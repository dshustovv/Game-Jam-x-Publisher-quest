#!/bin/bash
# Xsolla Player Uploader: prepare a game build and upload it with Build Loader (macOS host; bash 3.2 compatible).
#
# Game input: .zip .7z .rar .tar(.gz) .dmg, a folder, a .app, a portable .exe, or a Windows installer .exe/.msi
# (Inno Setup / NSIS / MSI are unpacked when innoextract / 7-Zip is available).
#
# Usage:
#   XSOLLA_BL_API_KEY=<key> bash bl_upload.sh --game <zip|dir|.app> --name "<Game name>" [options]
#   XSOLLA_BL_API_KEY=<key> bash bl_upload.sh --game-mac <...> --game-win <...> --name "<Game name>"   # one build, both OSes
# Options:
#   --platform auto|mac|win|both  target OS of the build (default auto = detected from the files)
#   --loader <BuildLoader.zip|dir> default: auto-discovered (unpacked copy, then *build*loader*.zip in Downloads/Desktop)
#   --descr "<text>"     build description (default: "<name> [<platform>] <timestamp>"), max 512 chars
#   --stage draft|none   draft = --set-build-on-test (default); none = no stage flag
#   --workdir <dir>      default: ~/xsolla_builds (Latin letters/digits, no spaces)
#   --ignore <json>      ignore list {"ignoring_files": [...]} -> --ignore-file-path + --use-ignore-file
#   --prepare-only       unpack/validate/report, do not call Build Loader
#   --retry-count 1..10  --retry-timeout 10..60  --chunk-size 10mb..500mb   passed to Build Loader (bad networks)
# Output: progress lines, "SUMMARY key=value" lines, final "RESULT: SUCCESS|FAILED: ..." line; exit 0 / 1.
# Publishing to players (--set-build-on-master) is deliberately not supported: it is a decision made in Player Account.

set -u
LOADER=""; GAME_IN=""; GAME_MAC=""; GAME_WIN=""; NAME=""; DESCR=""; STAGE="draft"; PLATFORM="auto"
WORKDIR="$HOME/xsolla_builds"; IGNORE=""; PREP_ONLY=0; RETRY_COUNT=""; RETRY_TIMEOUT=""; CHUNK=""
while [ $# -gt 0 ]; do
  case "$1" in
    --loader) LOADER="$2"; shift 2;;
    --game) GAME_IN="$2"; shift 2;;
    --game-mac) GAME_MAC="$2"; shift 2;;
    --game-win) GAME_WIN="$2"; shift 2;;
    --platform) PLATFORM="$2"; shift 2;;
    --name) NAME="$2"; shift 2;;
    --descr) DESCR="$2"; shift 2;;
    --stage) STAGE="$2"; shift 2;;
    --workdir) WORKDIR="$2"; shift 2;;
    --ignore) IGNORE="$2"; shift 2;;
    --prepare-only) PREP_ONLY=1; shift;;
    --retry-count) RETRY_COUNT="$2"; shift 2;;
    --retry-timeout) RETRY_TIMEOUT="$2"; shift 2;;
    --chunk-size) CHUNK="$2"; shift 2;;
    *) echo "unknown argument: $1"; exit 1;;
  esac
done

fail() { echo "RESULT: FAILED: $*"; exit 1; }
summary() { echo "SUMMARY $1=$2"; }
is_safe_path() { printf '%s' "$1" | LC_ALL=C grep -q '[^A-Za-z0-9_./-]' && return 1; return 0; }
OS=$(uname -s)

# ---------- 0. Arguments ----------
if [ -n "$GAME_MAC" ] || [ -n "$GAME_WIN" ]; then
  [ -z "$GAME_IN" ] || fail "use either --game or --game-mac/--game-win"
  if [ -n "$GAME_MAC" ] && [ -n "$GAME_WIN" ]; then PLATFORM="both"
  elif [ -n "$GAME_MAC" ]; then GAME_IN="$GAME_MAC"; GAME_MAC=""; PLATFORM="mac"
  else GAME_IN="$GAME_WIN"; GAME_WIN=""; PLATFORM="win"; fi
fi
case "$PLATFORM" in auto|mac|win|both) ;; *) fail "--platform must be auto, mac, win or both";; esac
[ "$PLATFORM" != "both" ] || [ -n "$GAME_MAC" ] || fail "--platform both needs --game-mac and --game-win"
for g in "$GAME_IN" "$GAME_MAC" "$GAME_WIN"; do [ -z "$g" ] || [ -e "$g" ] || fail "game not found: $g"; done
[ -n "$GAME_IN$GAME_MAC" ] || fail "--game is required"
FIRST="${GAME_IN:-$GAME_MAC}"
[ -n "$NAME" ] || { NAME=$(basename "$FIRST"); NAME="${NAME%.zip}"; NAME="${NAME%.app}"; }
SLUG=$(printf '%s' "$NAME" | LC_ALL=C tr -c 'A-Za-z0-9_-' '_' | sed 's/__*/_/g; s/^_//; s/_$//')
[ -n "$SLUG" ] || SLUG="game"
[ "$STAGE" = "draft" ] || [ "$STAGE" = "none" ] || fail "--stage must be draft or none"
[ "$PREP_ONLY" -eq 1 ] || [ -n "${XSOLLA_BL_API_KEY:-}" ] || \
  fail "XSOLLA_BL_API_KEY is empty (Player Account > your game > Set up > Builds > Game builds > API key)"
is_safe_path "$WORKDIR" || fail "workdir must be Latin letters/digits without spaces: $WORKDIR (use --workdir)"
TS=$(date +%Y%m%d-%H%M%S)

GAMEDIR="$WORKDIR/$SLUG/build"      # stable per game -> Build Loader sends patches on the next upload
LOGDIR="$WORKDIR/$SLUG/logs/$TS"
TOOLDIR="$WORKDIR/_build_loader"
mkdir -p "$GAMEDIR" "$LOGDIR" "$TOOLDIR" || fail "cannot create $WORKDIR"
summary game_name "$NAME"; summary build_dir "$GAMEDIR"; summary log_dir "$LOGDIR"

unzip_to() { if [ "$OS" = "Darwin" ]; then ditto -x -k "$1" "$2"; else unzip -q -o "$1" -d "$2"; fi; }
copy_tree() { # mirror $1 into $2
  if command -v rsync >/dev/null 2>&1; then rsync -a --delete "$1"/ "$2"/
  else rm -rf "$2"; mkdir -p "$2"; cp -R "$1"/. "$2"/; fi
}
# stage_input <src> <dest>: unpack/copy one game input into dest, lift a single wrapper folder; echoes the root dir
why() { echo "REASON: $*" >&2; }
find_7z() { # any 7-Zip CLI; for .7z only, Build Loader's own 7zr also works
  local t; for t in 7zz 7z 7za; do command -v "$t" >/dev/null 2>&1 && { command -v "$t"; return 0; }; done
  [ "${1:-}" = "7z" ] && [ -x "$TOOLDIR/Mac/7zr" ] && { echo "$TOOLDIR/Mac/7zr"; return 0; }
  return 1
}
has_bsdtar() { tar --version 2>/dev/null | grep -qi bsdtar; }   # macOS tar = libarchive: reads 7z and rar
extract_any() { # extract_any <file> <dst> <7z|rar|tar>
  local f="$1" d="$2" k="$3" z
  case "$k" in
    tar) tar -xf "$f" -C "$d" >&2 && return 0;;
    rar) command -v unar >/dev/null 2>&1 && unar -q -f -o "$d" "$f" >&2 && return 0
         z=$(find_7z rar) && "$z" x -y -o"$d" "$f" >&2 && return 0
         has_bsdtar && tar -xf "$f" -C "$d" >&2 && return 0
         why "no RAR extractor: install one (macOS: brew install unar; Windows: 7-Zip) or unpack the archive yourself"; return 3;;
    7z)  z=$(find_7z 7z) && "$z" x -y -o"$d" "$f" >&2 && return 0
         has_bsdtar && tar -xf "$f" -C "$d" >&2 && return 0
         why "no 7z extractor: install 7-Zip (macOS: brew install sevenzip) or unpack the archive yourself"; return 3;;
  esac
  return 1
}
mount_dmg() { # copy the visible contents of a .dmg (the .app and its files) into dst
  local f="$1" d="$2" m e
  if [ "$OS" != "Darwin" ]; then
    local z; z=$(find_7z dmg) && "$z" x -y -o"$d" "$f" >&2 && return 0
    why ".dmg can only be opened on macOS (or with 7-Zip)"; return 3
  fi
  m=$(mktemp -d /tmp/xlu_dmg.XXXXXX)
  yes | hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$m" "$f" >/dev/null 2>&1 \
    || { rmdir "$m"; why "hdiutil could not mount $f (damaged or encrypted image?)"; return 1; }
  for e in "$m"/*; do
    [ -L "$e" ] && continue                      # the 'Applications' shortcut
    ditto "$e" "$d/$(basename "$e")" || { hdiutil detach "$m" -force -quiet; return 1; }
  done
  hdiutil detach "$m" -quiet 2>/dev/null || hdiutil detach "$m" -force -quiet 2>/dev/null
  rmdir "$m" 2>/dev/null; return 0
}
installer_kind() { # prints inno | nsis | installshield | wix | msi | "" for a Windows .exe/.msi
  case "$1" in *.msi|*.MSI) echo msi; return;; esac
  local s; s=$(LC_ALL=C grep -a -o -m1 -E 'Inno Setup|Nullsoft Install System|NullsoftInst|InstallShield|WiX Toolset|Windows Installer XML' "$1" 2>/dev/null | head -1)
  case "$s" in "Inno Setup") echo inno;; Nullsoft*) echo nsis;; InstallShield) echo installshield;; WiX*|"Windows Installer XML") echo wix;; *) echo "";; esac
}
unpack_installer() { # unpack_installer <exe> <dst> <kind>
  local f="$1" d="$2" k="$3" z
  case "$k" in
    inno) command -v innoextract >/dev/null 2>&1 && innoextract -s -d "$d" "$f" >&2 && return 0
          why "Inno Setup installer: install innoextract (brew install innoextract / innoextract.constexpr.org) or install the game and pass the installed folder"; return 4;;
    nsis|msi|wix) z=$(find_7z exe) && "$z" x -y -o"$d" "$f" >&2 && { rm -rf "$d/\$PLUGINSDIR" "$d"/uninst*.exe 2>/dev/null; return 0; }
          why "$k installer: 7-Zip is needed to unpack it, or install the game and pass the installed folder"; return 4;;
    *) why "$k installer cannot be unpacked automatically: install the game and pass the installed folder"; return 4;;
  esac
}
fmt_of() { # human-readable input format for the report
  local l k; l=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  case "$l" in
    *.zip) echo zip;; *.7z) echo 7z;; *.rar) echo rar;; *.dmg) echo dmg;; *.app|*.app/) echo app;;
    *.tar|*.tar.gz|*.tgz|*.tar.xz|*.tar.bz2) echo tar;;
    *.exe|*.msi) k=$(installer_kind "$1"); [ -n "$k" ] && echo "installer-$k" || echo exe;;
    *) [ -d "$1" ] && echo folder || echo file;;
  esac
}
stage_input() {
  local src="$1" dst="$2" n=0 only="" e k rc
  rm -rf "$dst"; mkdir -p "$dst"
  case "$(printf '%s' "$src" | tr 'A-Z' 'a-z')" in
    *.zip) unzip_to "$src" "$dst" >&2 || return 1;;
    *.7z) extract_any "$src" "$dst" 7z || return $?;;
    *.rar) extract_any "$src" "$dst" rar || return $?;;
    *.tar|*.tar.gz|*.tgz|*.tar.xz|*.tar.bz2) extract_any "$src" "$dst" tar || return $?;;
    *.dmg) mount_dmg "$src" "$dst" || return $?;;
    *.app|*.app/) if [ "$OS" = "Darwin" ]; then ditto "$src" "$dst/$(basename "$src")"; else cp -R "$src" "$dst/"; fi;;
    *.exe|*.msi)
      k=$(installer_kind "$src")
      if [ -n "$k" ]; then
        echo "NOTE: $(basename "$src") is a $k installer, not the game itself — unpacking it" >&2
        unpack_installer "$src" "$dst" "$k" || return $?
      else
        cp "$src" "$dst/"     # portable single-file game
      fi;;
    *) if [ -d "$src" ]; then copy_tree "$src" "$dst" >&2
       elif [ -f "$src" ]; then cp "$src" "$dst/"; else return 1; fi;;
  esac
  rm -rf "$dst/__MACOSX"; find "$dst" -name .DS_Store -delete 2>/dev/null
  for e in "$dst"/* "$dst"/.[!.]*; do [ -e "$e" ] || continue; n=$((n+1)); only="$e"; done
  [ "$n" -gt 0 ] || return 2
  if [ "$n" -eq 1 ] && [ -d "$only" ]; then case "$only" in *.app) ;; *) echo "$only"; return 0;; esac; fi
  echo "$dst"
}
list_apps() { local e; for e in "$1"/*.app; do [ -d "$e" ] && basename "$e"; done; }
list_exes() {
  local e b; for e in "$1"/*.exe "$1"/*.EXE; do
    [ -f "$e" ] || continue; b=$(basename "$e")
    case "$(echo "$b" | tr 'A-Z' 'a-z')" in unins*|*crashhandler*|*crashreport*|vc_redist*|dxsetup*|*setup*) continue;; esac
    echo "$b"; done
}
detect_platform() { # mac | win | both | unknown
  local a w; a=$(list_apps "$1" | head -1); w=$(list_exes "$1" | head -1)
  if [ -n "$a" ] && [ -n "$w" ]; then echo both; elif [ -n "$a" ]; then echo mac; elif [ -n "$w" ]; then echo win; else echo unknown; fi
}

# ---------- 1. Build Loader (runs on THIS computer; the game's target OS does not matter) ----------
BL=""
if [ "$PREP_ONLY" -eq 0 ]; then
  [ "$OS" = "Darwin" ] || [ -n "${BL_TEST_ANY_OS:-}" ] || \
    fail "this script uploads from macOS; on Windows use bl_upload.ps1 (Build Loader has no Linux version)"
  if [ -z "$LOADER" ] && [ -x "$TOOLDIR/Mac/build_loader" ]; then LOADER="$TOOLDIR"; fi
  if [ -z "$LOADER" ]; then
    LOADER=$(find "$HOME/Downloads" "$HOME/Desktop" -maxdepth 2 -type f -iname '*build*loader*.zip' 2>/dev/null \
             | grep -iv win | head -1)
  fi
  [ -n "$LOADER" ] || fail "Build Loader not found. Download BuildLoader.zip (Mac) in Player Account > your game > Set up > Builds > Game builds, save it to Downloads and rerun"
  if [ -f "$LOADER" ]; then
    rm -rf "$TOOLDIR"; mkdir -p "$TOOLDIR"; unzip_to "$LOADER" "$TOOLDIR" || fail "cannot unpack Build Loader: $LOADER"
    LOADER="$TOOLDIR"
  fi
  for c in "$LOADER/Mac/build_loader" "$LOADER/build_loader"; do [ -x "$c" ] && { BL="$c"; break; }; done
  [ -n "$BL" ] || fail "build_loader not found in $LOADER (expected Mac/build_loader inside BuildLoader.zip)"
  xattr -dr com.apple.quarantine "$(dirname "$BL")" 2>/dev/null
  if [ "$(uname -m)" = "arm64" ] && ! file "$BL" | grep -q arm64; then
    /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null || \
      fail "Build Loader is Intel-only and Rosetta is not installed. Run: softwareupdate --install-rosetta --agree-to-license"
  fi
  summary build_loader "$BL"
fi

# ---------- 2. Prepare the build folder ----------
# Build Loader registers every build for the OS it was built for (a constant inside the program, sent as
# ?platform=…): the Mac Build Loader always creates macOS builds. So from a Mac only macOS builds can be uploaded.
HOST="${BL_TEST_HOST:-mac}"; OTHER=win; [ "$HOST" = win ] && OTHER=mac
PENDING=""
if [ "$PLATFORM" = "both" ] && [ "$PREP_ONLY" -eq 0 ]; then
  # one upload = one platform: take this computer's part, the other must be uploaded from a computer with that OS
  if [ "$HOST" = mac ]; then GAME_IN="$GAME_MAC"; PENDING="$GAME_WIN"; else GAME_IN="$GAME_WIN"; PENDING="$GAME_MAC"; fi
  PLATFORM="auto"
fi
INC="$WORKDIR/$SLUG/_incoming"; rm -rf "$INC"
if [ "$PLATFORM" = "both" ]; then
  RW=$(stage_input "$GAME_WIN" "$INC/win") || fail "cannot prepare the Windows build: $GAME_WIN (see REASON above)"
  RM=$(stage_input "$GAME_MAC" "$INC/mac") || fail "cannot prepare the macOS build: $GAME_MAC (see REASON above)"
  [ "$(detect_platform "$RW")" = "win" ] || fail "--game-win has no .exe in its root (or it is a macOS build): $GAME_WIN"
  [ "$(detect_platform "$RM")" = "mac" ] || fail "--game-mac has no .app in its root (or it is a Windows build): $GAME_MAC"
  # both trees go into one build root; a file present in both with different content would be overwritten
  CONFLICTS=$(cd "$RM" && find . -type f | while read -r f; do
      [ -f "$RW/$f" ] && ! cmp -s "$f" "$RW/$f" && echo "${f#./}"; done)
  [ -z "$CONFLICTS" ] || { echo "conflicting files:"; echo "$CONFLICTS" | head -20; fail "macOS and Windows builds contain different files with the same path — upload them as separate games or rename"; }
  mkdir -p "$INC/merged"; cp -R "$RW"/. "$INC/merged"/; cp -R "$RM"/. "$INC/merged"/
  ROOT="$INC/merged"
else
  ROOT=$(stage_input "$GAME_IN" "$INC/one"); rc=$?
  [ $rc -ne 2 ] || fail "the game archive/folder is empty"
  [ $rc -eq 0 ] || fail "cannot prepare $GAME_IN (see REASON above)"
  DET=$(detect_platform "$ROOT")
  if [ -n "$PENDING" ] && [ "$DET" = "$OTHER" ]; then      # the two files were given the other way round
    T="$GAME_IN"; GAME_IN="$PENDING"; PENDING="$T"
    ROOT=$(stage_input "$GAME_IN" "$INC/one") || fail "cannot prepare $GAME_IN (see REASON above)"; DET=$(detect_platform "$ROOT")
  fi
  if [ "$PLATFORM" = "auto" ]; then
    PLATFORM="$DET"
  elif [ "$DET" != "unknown" ] && [ "$DET" != "$PLATFORM" ] && [ "$DET" != "both" ]; then
    fail "you chose --platform $PLATFORM, but the build looks like $DET (root has $( [ "$DET" = mac ] && echo .app || echo .exe ))"
  fi
  TARGET="$PLATFORM"; case "$TARGET" in mac|win) ;; *) TARGET="$HOST";; esac
  if [ "$TARGET" != "$HOST" ]; then
    MSG="this is a $TARGET build, but this computer uploads $HOST builds: Build Loader registers a build for the OS of the computer it runs on"
    if [ "$PREP_ONLY" -eq 0 ]; then
      echo "REASON: $MSG"; echo "HINT: upload it from a $( [ "$TARGET" = win ] && echo Windows || echo Mac ) computer with the $( [ "$TARGET" = win ] && echo Windows || echo Mac ) BuildLoader.zip"
      echo "RESULT: FAILED: wrong computer for a $TARGET build"; exit 2
    fi
    echo "WARNING: $MSG"
  fi
  [ "$DET" != "both" ] || echo "WARNING: the build root has both .app and .exe — it will be registered as a $HOST build only"
fi
summary uploads_as "$HOST"
[ -z "$PENDING" ] || summary pending "upload $(basename "$PENDING") from a $( [ "$OTHER" = win ] && echo Windows || echo Mac ) computer with the same key"
copy_tree "$ROOT" "$GAMEDIR" || fail "cannot copy build into $GAMEDIR"
rm -rf "$INC"
# zips made on Windows carry no Unix permissions -> the .app binary loses +x and the game will not start
for b in "$GAMEDIR"/*.app/Contents/MacOS/*; do
  [ -f "$b" ] || continue
  if [ ! -x "$b" ]; then chmod +x "$b"; echo "FIXED: made executable: ${b#$GAMEDIR/}"; fi
done

SIZE_KB=$(du -sk "$GAMEDIR" | cut -f1); FREE_KB=$(df -k "$WORKDIR" | awk 'NR==2{print $4}')
summary build_size_mb $((SIZE_KB/1024)); summary free_disk_mb $((FREE_KB/1024))
[ "$FREE_KB" -ge $((SIZE_KB*3/2)) ] || echo "WARNING: free disk < 1.5 x build size (Build Loader requirement)"
echo "build root:"; ls -1 "$GAMEDIR" | sed 's/^/  /'
APPS=$(list_apps "$GAMEDIR" | tr '\n' '|' | sed 's/|$//'); EXES=$(list_exes "$GAMEDIR" | tr '\n' '|' | sed 's/|$//')
if [ -n "$GAME_IN" ]; then summary input_format "$(fmt_of "$GAME_IN")"; else summary input_format "mac:$(fmt_of "$GAME_MAC") win:$(fmt_of "$GAME_WIN")"; fi
summary platform "$PLATFORM"; summary executable_macos "${APPS:-none}"; summary executable_windows "${EXES:-none}"
[ "$PLATFORM" != "unknown" ] || echo "WARNING: no .app or .exe in the build root — the launcher starts a file from the build root"
[ -n "$DESCR" ] || DESCR="$NAME [$PLATFORM] $TS"
[ ${#DESCR} -le 512 ] || fail "description longer than 512 characters"

if [ "$PREP_ONLY" -eq 1 ]; then echo "RESULT: SUCCESS: prepared (no upload): $GAMEDIR"; exit 0; fi

# ---------- 3. Build Loader: init + update ----------
KEY="$XSOLLA_BL_API_KEY"
MASK="$(printf '%s' "$KEY" | cut -c1-4)…$(printf '%s' "$KEY" | rev | cut -c1-3 | rev)"
mask() { sed "s/$KEY/$MASK/g"; }
result_of() { grep -Eo 'Result: *[A-Za-z]+' "$1" | tail -1 | sed 's/Result: *//'; }
run_bl() { # run_bl <logname> args... ; live output in <logname>.raw, masked copy in <logname>.log
  local name="$1"; shift
  "$BL" "$@" > "$LOGDIR/$name.raw" 2>&1; local rc=$?
  mask < "$LOGDIR/$name.raw" > "$LOGDIR/$name.log"; rm -f "$LOGDIR/$name.raw"
  return $rc
}

# init every time: the key is per game and Build Loader keeps one global config
run_bl init --init --api-key "$KEY" --game-path "$GAMEDIR"; RC=$?
R=$(result_of "$LOGDIR/init.log"); summary init_exit $RC; summary init_result "${R:-?}"
if [ $RC -ne 0 ] || { [ -n "$R" ] && [ "$R" != "success" ]; }; then
  tail -n 25 "$LOGDIR/init.log"; fail "init (exit $RC, result ${R:-?}) — see $LOGDIR/init.log"
fi

set -- --update --game-path "$GAMEDIR" --descr "$DESCR" --no-progressbar
[ "$STAGE" = "draft" ] && set -- "$@" --set-build-on-test
if [ -n "$IGNORE" ]; then [ -f "$IGNORE" ] || fail "ignore list not found: $IGNORE"; set -- "$@" --ignore-file-path "$IGNORE" --use-ignore-file; fi
[ -z "$RETRY_COUNT" ] || set -- "$@" --retry-count "$RETRY_COUNT"
[ -z "$RETRY_TIMEOUT" ] || set -- "$@" --retry-timeout "$RETRY_TIMEOUT"
[ -z "$CHUNK" ] || set -- "$@" --chunk-size "$CHUNK"
summary descr "$DESCR"; summary stage "$STAGE"
echo "uploading… (first upload sends the whole build; later uploads of the same game send patches)"
T0=$(date +%s)
run_bl update "$@"; RC=$?
R=$(result_of "$LOGDIR/update.log")
summary update_exit $RC; summary update_result "${R:-?}"; summary update_seconds $(( $(date +%s) - T0 ))
run_bl builds_list --builds-list

if [ $RC -ne 0 ] || { [ -n "$R" ] && [ "$R" != "success" ]; }; then
  tail -n 40 "$LOGDIR/update.log"; fail "update (exit $RC, result ${R:-?}) — see $LOGDIR/update.log"
fi
tail -n 15 "$LOGDIR/update.log"
echo "RESULT: SUCCESS: uploaded \"$DESCR\" (${STAGE}) from $GAMEDIR"
exit 0
