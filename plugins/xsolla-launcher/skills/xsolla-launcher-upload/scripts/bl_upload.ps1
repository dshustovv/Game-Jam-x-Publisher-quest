# Xsolla Player Uploader: prepare a game build and upload it with Build Loader (Windows host, PowerShell 5.1+).
#
# Usage (key via environment variable):
#   $env:XSOLLA_BL_API_KEY = '<key>'
#   powershell -NoProfile -ExecutionPolicy Bypass -File bl_upload.ps1 -Game <zip|dir|exe> -Name "<Game name>"
#   ... -GameWin <zip|dir> -GameMac <zip|dir> -Name "<Game name>"      # one build for both OSes
# Game input: .zip .7z .rar .tar(.gz) .dmg, a folder, a .app, a portable .exe, or a Windows installer .exe/.msi
# (.7z/.rar/.dmg/NSIS/MSI need 7-Zip; Inno Setup needs innoextract).
# Options: -Platform auto|mac|win|both  -Loader <BuildLoader.zip|dir>  -Descr "<text>"  -Stage draft|none
#          -WorkDir C:\xsolla_builds  -Ignore <json>  -PrepareOnly
#          -RetryCount 1..10  -RetryTimeout 10..60  -ChunkSize 10mb..500mb   (passed to Build Loader; bad networks)
# Output: progress lines, "SUMMARY key=value" lines, final "RESULT: SUCCESS|FAILED: ..." line; exit 0/1.
# Publishing to players (--set-build-on-master) is deliberately not supported.
# Note: Windows file systems have no Unix "executable" bit — upload macOS builds from a Mac when possible.

param(
  [string]$Game = "", [string]$GameMac = "", [string]$GameWin = "",
  [ValidateSet("auto", "mac", "win", "both")][string]$Platform = "auto",
  [string]$Loader = "", [string]$Name = "", [string]$Descr = "",
  [ValidateSet("draft", "none")][string]$Stage = "draft",
  [string]$WorkDir = "C:\xsolla_builds", [string]$Ignore = "", [switch]$PrepareOnly,
  [string]$RetryCount = "", [string]$RetryTimeout = "", [string]$ChunkSize = ""
)
$ErrorActionPreference = "Stop"
$PSNativeCommandArgumentPassing = 'Legacy'   # PowerShell 7.3+: pass the cmd.exe line unchanged (no-op in 5.1)
trap { Write-Output "RESULT: FAILED: $($_.Exception.Message)"; exit 1 }
function Fail($m) { Write-Output "RESULT: FAILED: $m"; exit 1 }
function Summary($k, $v) { Write-Output "SUMMARY $k=$v" }
function Write-Utf8($path, $text) { [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding $false)) }

# ---------- 0. Arguments ----------
if ($GameMac -or $GameWin) {
  if ($Game) { Fail "use either -Game or -GameMac/-GameWin" }
  if ($GameMac -and $GameWin) { $Platform = "both" }
  elseif ($GameMac) { $Game = $GameMac; $GameMac = ""; $Platform = "mac" }
  else { $Game = $GameWin; $GameWin = ""; $Platform = "win" }
}
if ($Platform -eq "both" -and -not ($GameMac -and $GameWin)) { Fail "-Platform both needs -GameMac and -GameWin" }
foreach ($g in @($Game, $GameMac, $GameWin)) { if ($g -and -not (Test-Path -LiteralPath $g)) { Fail "game not found: $g" } }
if (-not ($Game -or $GameMac)) { Fail "-Game is required" }
if (-not $PrepareOnly -and -not $env:XSOLLA_BL_API_KEY) {
  Fail "XSOLLA_BL_API_KEY is empty (Player Account (sign in at xsolla.com/for/free-to-play-pc) > your game > Set up > Builds > Game builds > API key)"
}
$first = if ($Game) { $Game } else { $GameMac }
if (-not $Name) { $Name = [IO.Path]::GetFileNameWithoutExtension($first) -replace '\.(app|tar|exe|msi)$', '' }
$Slug = ($Name -replace '[^A-Za-z0-9_-]', '_' -replace '_+', '_').Trim('_'); if (-not $Slug) { $Slug = "game" }
if ($WorkDir -notmatch '^[A-Za-z]:\\[A-Za-z0-9_.\\-]*$') { Fail "WorkDir must be Latin letters/digits without spaces: $WorkDir" }
$TS = Get-Date -Format "yyyyMMdd-HHmmss"

$GameDir = Join-Path $WorkDir "$Slug\build"        # stable per game -> next upload is a patch
$LogDir = Join-Path $WorkDir "$Slug\logs\$TS"
$ToolDir = Join-Path $WorkDir "_build_loader"
New-Item -ItemType Directory -Force $GameDir, $LogDir, $ToolDir | Out-Null
Summary game_name $Name; Summary build_dir $GameDir; Summary log_dir $LogDir

function Find-7z {
  $c = Get-Command 7z, 7za, 7zz -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($c) { return $c.Source }
  foreach ($p in @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe")) { if ($p -and (Test-Path $p)) { return $p } }
  return $null
}
function Extract-With7z([string]$f, [string]$d, [string]$what) {
  $z = Find-7z
  if ($z) { & $z x -y "-o$d" $f | Out-Null; if ($LASTEXITCODE -eq 0) { return } }
  # Windows 10+ tar.exe (libarchive) reads .tar/.tgz and, on recent builds, .7z/.rar
  if ($what -ne "installer") {
    try { & tar.exe -xf $f -C $d 2>$null; if ($LASTEXITCODE -eq 0) { return } } catch { }   # PS5 + Stop: stderr would throw
  }
  Fail "cannot unpack $what $(Split-Path $f -Leaf): install 7-Zip (winget install 7zip.7zip) or unpack it yourself"
}
function Installer-Kind([string]$f) {   # inno | nsis | installshield | wix | msi | ""
  if ($f -match '\.msi$') { return "msi" }
  $len = (Get-Item -LiteralPath $f).Length; $n = [Math]::Min($len, 8MB)
  $fs = [IO.File]::OpenRead($f); try { $buf = New-Object byte[] $n; [void]$fs.Read($buf, 0, $n) } finally { $fs.Close() }
  $t = [Text.Encoding]::ASCII.GetString($buf)
  if ($t -match 'Inno Setup') { "inno" } elseif ($t -match 'Nullsoft') { "nsis" } elseif ($t -match 'InstallShield') { "installshield" }
  elseif ($t -match 'WiX Toolset|Windows Installer XML') { "wix" } else { "" }
}
function Format-Of([string]$f) {
  switch -regex ($f.ToLower()) {
    '\.zip$' { "zip" } '\.7z$' { "7z" } '\.rar$' { "rar" } '\.dmg$' { "dmg" } '\.app\\?$' { "app" }
    '\.(tar|tgz|tar\.gz|tar\.xz|tar\.bz2)$' { "tar" }
    '\.(exe|msi)$' { $k = Installer-Kind $f; if ($k) { "installer-$k" } else { "exe" } }
    default { if (Test-Path -LiteralPath $f -PathType Container) { "folder" } else { "file" } }
  }
}
function Stage-Input([string]$src, [string]$dst) {   # returns the build root inside $dst
  Remove-Item -Recurse -Force $dst -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force $dst | Out-Null
  $fmt = Format-Of $src
  switch -regex ($fmt) {
    '^zip$' { Expand-Archive -LiteralPath $src -DestinationPath $dst -Force }
    '^(7z|rar|tar)$' { Extract-With7z $src $dst $fmt }
    '^dmg$' { Write-Output "NOTE: .dmg on Windows is unpacked with 7-Zip; prefer uploading macOS builds from a Mac" | Out-Host; Extract-With7z $src $dst "dmg" }
    '^installer-inno$' {
      Write-Host "NOTE: $(Split-Path $src -Leaf) is an Inno Setup installer, not the game itself - unpacking it"
      $ie = Get-Command innoextract -ErrorAction SilentlyContinue
      if (-not $ie) { Fail "Inno Setup installer: install innoextract (innoextract.constexpr.org) or install the game and pass the installed folder" }
      & $ie.Source -s -d $dst $src | Out-Null; if ($LASTEXITCODE -ne 0) { Fail "innoextract failed on $src" }
    }
    '^installer-(nsis|msi|wix)$' {
      Write-Host "NOTE: $(Split-Path $src -Leaf) is a $($fmt -replace 'installer-','') installer, not the game itself - unpacking it"
      Extract-With7z $src $dst "installer"
      Remove-Item -Recurse -Force "$dst\`$PLUGINSDIR" -ErrorAction SilentlyContinue
      Get-ChildItem $dst -Filter 'uninst*.exe' -File -ErrorAction SilentlyContinue | Remove-Item -Force
    }
    '^installer-' { Fail "$fmt cannot be unpacked automatically: install the game and pass the installed folder" }
    '^app$' { Copy-Item -LiteralPath $src -Destination $dst -Recurse }
    '^folder$' { robocopy $src $dst /MIR /NJH /NJS /NFL /NDL /NP | Out-Null }
    default { Copy-Item -LiteralPath $src $dst }    # portable single-file .exe or other file
  }
  Remove-Item -Recurse -Force "$dst\__MACOSX" -ErrorAction SilentlyContinue
  Get-ChildItem $dst -Recurse -Force -Filter .DS_Store -ErrorAction SilentlyContinue | Remove-Item -Force
  $items = @(Get-ChildItem -LiteralPath $dst -Force)
  if ($items.Count -eq 0) { Fail "the game archive/folder is empty: $src" }
  if ($items.Count -eq 1 -and $items[0].PSIsContainer -and $items[0].Name -notmatch '\.app$') { return $items[0].FullName }
  return $dst
}
function List-Exes($d) { @(Get-ChildItem $d -Filter *.exe -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^(unins|vc_redist|dxsetup)|crashhandler|crashreport|^setup(\.exe$|[_-])|[_-]setup\.exe$' } | ForEach-Object Name) }
function List-Apps($d) { @(Get-ChildItem $d -Filter *.app -Directory -ErrorAction SilentlyContinue | ForEach-Object Name) }
function Detect-Platform($d) {
  $a = List-Apps $d; $w = List-Exes $d
  if ($a -and $w) { "both" } elseif ($a) { "mac" } elseif ($w) { "win" } else { "unknown" }
}

# ---------- 1. Build Loader (runs on THIS computer; the game's target OS does not matter) ----------
$BL = $null
if (-not $PrepareOnly) {
  if (-not $Loader -and (Test-Path "$ToolDir\Win\build_loader.exe")) { $Loader = $ToolDir }
  if (-not $Loader) {
    $z = Get-ChildItem "$HOME\Downloads", "$HOME\Desktop" -Filter *.zip -File -ErrorAction SilentlyContinue |
         Where-Object { $_.Name -match 'build.?loader' -and $_.Name -notmatch 'mac' } | Select-Object -First 1
    if ($z) { $Loader = $z.FullName }
  }
  if (-not $Loader) { Fail "Build Loader not found. Download BuildLoader.zip (Windows) in Player Account (sign in at xsolla.com/for/free-to-play-pc) > your game > Set up > Builds > Game builds, save it to Downloads and rerun" }
  if (Test-Path -LiteralPath $Loader -PathType Leaf) {
    Remove-Item -Recurse -Force $ToolDir -ErrorAction SilentlyContinue
    Expand-Archive -LiteralPath $Loader -DestinationPath $ToolDir -Force
    $Loader = $ToolDir
  }
  foreach ($c in @("$Loader\Win\build_loader.exe", "$Loader\build_loader.exe")) { if (Test-Path $c) { $BL = $c; break } }
  if (-not $BL) { Fail "build_loader.exe not found in $Loader (expected Win\build_loader.exe inside BuildLoader.zip)" }
  Get-ChildItem (Split-Path $BL) -Recurse | Unblock-File -ErrorAction SilentlyContinue
  Summary build_loader $BL
}

# ---------- 2. Prepare the build folder ----------
# Build Loader registers every build for the OS it was built for: the Windows Build Loader always creates Windows
# builds. So from a PC only Windows builds can be uploaded.
$Pending = $null
if ($Platform -eq "both" -and -not $PrepareOnly) { $Game = $GameWin; $Pending = $GameMac; $Platform = "auto" }
$Inc = Join-Path $WorkDir "$Slug\_incoming"
Remove-Item -Recurse -Force $Inc -ErrorAction SilentlyContinue
if ($Platform -eq "both") {
  $rw = Stage-Input $GameWin "$Inc\win"; $rm = Stage-Input $GameMac "$Inc\mac"
  if ((Detect-Platform $rw) -ne "win") { Fail "-GameWin has no .exe in its root (or it is a macOS build): $GameWin" }
  if ((Detect-Platform $rm) -ne "mac") { Fail "-GameMac has no .app in its root (or it is a Windows build): $GameMac" }
  $conf = @(Get-ChildItem $rm -Recurse -File | ForEach-Object {
      $rel = $_.FullName.Substring($rm.Length).TrimStart('\'); $o = Join-Path $rw $rel
      if ((Test-Path -LiteralPath $o) -and (Get-FileHash -LiteralPath $o).Hash -ne (Get-FileHash -LiteralPath $_.FullName).Hash) { $rel } })
  if ($conf.Count) { $conf | Select-Object -First 20; Fail "macOS and Windows builds contain different files with the same path - upload them as separate games or rename" }
  $root = "$Inc\merged"; New-Item -ItemType Directory -Force $root | Out-Null
  robocopy $rw $root /E /NJH /NJS /NFL /NDL /NP | Out-Null; robocopy $rm $root /E /NJH /NJS /NFL /NDL /NP | Out-Null
} else {
  $root = Stage-Input $Game "$Inc\one"
  $det = Detect-Platform $root
  if ($Pending -and $det -eq "mac") { $t = $Game; $Game = $Pending; $Pending = $t; $root = Stage-Input $Game "$Inc\one"; $det = Detect-Platform $root }
  if ($Platform -eq "auto") { $Platform = $det }
  elseif ($det -ne "unknown" -and $det -ne "both" -and $det -ne $Platform) {
    Fail "you chose -Platform $Platform, but the build looks like $det"
  }
  $target = if ($Platform -in "mac", "win") { $Platform } else { "win" }
  if ($target -eq "mac") {
    $msg = "this is a macOS build, but this computer uploads Windows builds: Build Loader registers a build for the OS of the computer it runs on"
    if (-not $PrepareOnly) { Write-Output "REASON: $msg"; Write-Output "HINT: upload it from a Mac with the Mac BuildLoader.zip"; Write-Output "RESULT: FAILED: wrong computer for a macOS build"; exit 2 }
    Write-Output "WARNING: $msg"
  }
  if ($det -eq "both") { Write-Output "WARNING: the build root has both .app and .exe - it will be registered as a Windows build only" }
}
Summary uploads_as "win"
if ($Pending) { Summary pending "upload $(Split-Path $Pending -Leaf) from a Mac with the same key" }
robocopy $root $GameDir /MIR /NJH /NJS /NFL /NDL /NP | Out-Null
if ($LASTEXITCODE -ge 8) { Fail "cannot copy build into $GameDir (robocopy $LASTEXITCODE)" }
Remove-Item -Recurse -Force $Inc -ErrorAction SilentlyContinue

$sizeMB = [int]((Get-ChildItem $GameDir -Recurse -File | Measure-Object Length -Sum).Sum / 1MB)
$freeMB = [int]((Get-PSDrive (Get-Item $WorkDir).PSDrive.Name).Free / 1MB)
Summary build_size_mb $sizeMB; Summary free_disk_mb $freeMB
if ($freeMB -lt $sizeMB * 1.5) { Write-Output "WARNING: free disk < 1.5 x build size (Build Loader requirement)" }
Write-Output "build root:"; Get-ChildItem $GameDir | ForEach-Object { "  " + $_.Name }
$exe = List-Exes $GameDir; $app = List-Apps $GameDir
Summary input_format ($(if ($Game) { Format-Of $Game } else { "mac:$(Format-Of $GameMac) win:$(Format-Of $GameWin)" }))
Summary platform $Platform
Summary executable_windows ($(if ($exe) { $exe -join '|' } else { "none" }))
Summary executable_macos ($(if ($app) { $app -join '|' } else { "none" }))
if ($Platform -eq "unknown") { Write-Output "WARNING: no .exe or .app in the build root - the launcher starts a file from the build root" }
if (-not $Descr) { $Descr = "$Name [$Platform] $TS" }
if ($Descr.Length -gt 512) { Fail "description longer than 512 characters" }

if ($PrepareOnly) { Write-Output "RESULT: SUCCESS: prepared (no upload): $GameDir"; exit 0 }

# ---------- 3. Build Loader: init + update ----------
$Key = $env:XSOLLA_BL_API_KEY
if ($Key -match '[%"^&|<>\s]') { Write-Output "REASON: the API key contains a space or one of % `" ^ & | < > , which cmd.exe would misread. Copy the key again from Player Account (it should be letters, digits and dashes only)."; Write-Output "RESULT: FAILED: unusual characters in the API key"; exit 2 }
$Mask = if ($Key.Length -ge 12) { $Key.Substring(0, 4) + "..." + $Key.Substring($Key.Length - 3) } else { "****" }

function Run-BL([string]$logName, [string[]]$blArgs) {
  # cmd.exe redirection streams the log live (poll <name>.raw while it runs) and keeps the tool's own encoding
  # (PowerShell 5 '>' would write UTF-16). /s + outer quotes: cmd strips exactly the outer pair.
  $raw = Join-Path $LogDir "$logName.raw"
  $quoted = ($blArgs | ForEach-Object { if ($_ -match '[\s&|<>^]') { '"' + $_ + '"' } else { $_ } }) -join ' '
  $line = "`"$BL`" $quoted > `"$raw`" 2>&1"
  & cmd.exe /s /c "`"$line`""
  $code = $LASTEXITCODE
  $text = [IO.File]::ReadAllText($raw).Replace($Key, $Mask)
  Write-Utf8 (Join-Path $LogDir "$logName.log") $text
  Remove-Item $raw -Force
  $m = [regex]::Matches($text, 'Result:\s*([A-Za-z]+)')
  $res = if ($m.Count) { $m[$m.Count - 1].Groups[1].Value } else { "?" }
  return @($code, $res, $text)
}

# init every time: the key is per game and Build Loader keeps one global config
$r = Run-BL "init" @("--init", "--api-key", $Key, "--game-path", $GameDir)
Summary init_exit $r[0]; Summary init_result $r[1]
if ($r[0] -ne 0 -or ($r[1] -ne "?" -and $r[1] -ne "success")) {
  ($r[2] -split "`n" | Select-Object -Last 25) -join "`n"; Fail "init (exit $($r[0]), result $($r[1])) - see $LogDir\init.log"
}
$a = @("--update", "--game-path", $GameDir, "--descr", $Descr, "--no-progressbar")
if ($Stage -eq "draft") { $a += "--set-build-on-test" }
if ($Ignore) { if (-not (Test-Path $Ignore)) { Fail "ignore list not found: $Ignore" }; $a += @("--ignore-file-path", $Ignore, "--use-ignore-file") }
if ($RetryCount) { $a += @("--retry-count", $RetryCount) }
if ($RetryTimeout) { $a += @("--retry-timeout", $RetryTimeout) }
if ($ChunkSize) { $a += @("--chunk-size", $ChunkSize) }
Summary descr $Descr; Summary stage $Stage
Write-Output "uploading... (first upload sends the whole build; later uploads of the same game send patches)"
$t0 = Get-Date
$r = Run-BL "update" $a
Summary update_exit $r[0]; Summary update_result $r[1]; Summary update_seconds ([int]((Get-Date) - $t0).TotalSeconds)
Run-BL "builds_list" @("--builds-list") | Out-Null
if ($r[0] -ne 0 -or ($r[1] -ne "?" -and $r[1] -ne "success")) {
  ($r[2] -split "`n" | Select-Object -Last 40) -join "`n"; Fail "update (exit $($r[0]), result $($r[1])) - see $LogDir\update.log"
}
($r[2] -split "`n" | Select-Object -Last 15) -join "`n"
Write-Output "RESULT: SUCCESS: uploaded `"$Descr`" ($Stage) from $GameDir"
exit 0
