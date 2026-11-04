# Download the generated launcher installer(s) from the links in Player Account (Launcher build > Get installer),
# check the Authenticode signature, optionally start the installer. Windows, PowerShell 5.1+.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File get_launcher.ps1 -Url <link>[,<link>] [-Out <dir>] [-Open]
# Output: "SUMMARY key=value" lines and a final "RESULT: SUCCESS|FAILED: ..." line; exit 0/1.

param([Parameter(Mandatory = $true)][string[]]$Url, [string]$Out = "C:\xsolla_builds\_launcher", [switch]$Open)
$ErrorActionPreference = "Stop"
trap { Write-Output "RESULT: FAILED: $($_.Exception.Message)"; exit 1 }
function Fail($m) { Write-Output "RESULT: FAILED: $m"; exit 1 }
function Summary($k, $v) { Write-Output "SUMMARY $k=$v" }
$Url = @($Url | ForEach-Object { $_ -split ',' } | Where-Object { $_ })   # "-Url a,b" via -File arrives as one string
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Dir = Join-Path $Out (Get-Date -Format "yyyyMMdd-HHmmss"); New-Item -ItemType Directory -Force $Dir | Out-Null
Summary out_dir $Dir
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with the progress bar in PS 5

foreach ($u in $Url) {
  if ($u -notmatch '^https://') { Write-Output "SKIP (not https): $u"; continue }
  Write-Output "downloading from $(([Uri]$u).Host) ..."
  $resp = Invoke-WebRequest -Uri $u -UseBasicParsing -Method Head -ErrorAction SilentlyContinue
  $name = $null
  if ($resp -and $resp.Headers['Content-Disposition'] -match 'filename="?([^";]+)') { $name = $Matches[1] }
  if (-not $name) { $name = [IO.Path]::GetFileName(([Uri]$u).AbsolutePath); if (-not $name) { $name = "launcher_installer.exe" } }
  Invoke-WebRequest -Uri $u -OutFile (Join-Path $Dir $name) -UseBasicParsing
}
$files = @(Get-ChildItem $Dir -File)
if (-not $files) { Fail "nothing downloaded - the link may have expired; copy it again from Get installer" }
foreach ($f in $files) {
  Summary file $f.Name; Summary size_mb ([int]($f.Length / 1MB))
  if ($f.Extension -in '.exe', '.msi') {
    $s = Get-AuthenticodeSignature $f.FullName
    Summary signature "$($s.Status) | $($s.SignerCertificate.Subject)"
  } else { Summary signature "not a Windows installer ($($f.Extension))" }
}
if ($Open) {
  $inst = $files | Where-Object { $_.Extension -in '.exe', '.msi' } | Sort-Object Length -Descending | Select-Object -First 1
  if (-not $inst) { Fail "no Windows installer (.exe/.msi) among the downloads" }
  Start-Process $inst.FullName
  Write-Output "started $($inst.Name) - follow the installer, then start the launcher once and sign in"
}
Write-Output "RESULT: SUCCESS: downloaded to $Dir"
exit 0
