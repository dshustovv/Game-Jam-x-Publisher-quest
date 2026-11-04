#!/bin/bash
# Download the generated launcher installer(s) from the links in Player Account (Launcher build > Get installer),
# check the signature, optionally start the installer. macOS host; bash 3.2 compatible.
#
# Usage: bash get_launcher.sh --url <link> [--url <link> ...] [--out <dir>] [--open]
# Output: "SUMMARY key=value" lines and a final "RESULT: SUCCESS|FAILED: ..." line; exit 0 / 1.

set -u
URLS=""; OUT="$HOME/xsolla_builds/_launcher"; OPEN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --url) URLS="$URLS
$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    --open) OPEN=1; shift;;
    *) echo "unknown argument: $1"; exit 1;;
  esac
done
fail() { echo "RESULT: FAILED: $*"; exit 1; }
summary() { echo "SUMMARY $1=$2"; }
[ -n "$URLS" ] || fail "--url is required (Player Account (sign in at xsolla.com/for/free-to-play-pc) > Launcher > Edit launcher > Settings > Launcher build > Get installer)"
TS=$(date +%Y%m%d-%H%M%S); DIR="$OUT/$TS"; mkdir -p "$DIR" || fail "cannot create $DIR"
summary out_dir "$DIR"
OK=0; BAD=0; LAST=""

check_sig() { # prints a one-line verdict for a downloaded file
  local f="$1"
  case "$f" in
    *.dmg) codesign -dv --verbose=2 "$f" 2>&1 | grep -E '^Authority=' | head -1
           spctl -a -t open --context context:primary-signature -v "$f" 2>&1 | tail -1;;
    *.pkg) pkgutil --check-signature "$f" 2>&1 | sed -n '1,3p';;
    *.zip) local t; t=$(mktemp -d); ditto -x -k "$f" "$t" 2>/dev/null
           for a in "$t"/*.app; do [ -d "$a" ] && { codesign -dv --verbose=2 "$a" 2>&1 | grep -E '^Authority=' | head -1; spctl -a -vv "$a" 2>&1 | tail -2; }; done
           rm -rf "$t";;
    *.exe|*.msi) echo "Windows installer — signature can be checked on Windows (Get-AuthenticodeSignature)";;
    *) echo "unknown type: $(file -b "$f" | cut -c1-60)";;
  esac
}

echo "$URLS" | while read -r u; do
  [ -n "$u" ] || continue
  case "$u" in https://*) ;; *) echo "SKIP (not https): $u"; continue;; esac
  host=$(printf '%s' "$u" | sed -E 's#https://([^/]+).*#\1#')
  echo "downloading from $host …"
  ( cd "$DIR" && curl -fL --retry 3 -sS -O -J "$u" ) || { echo "FAILED download: $u"; continue; }
done

FILES=$(ls -1t "$DIR" 2>/dev/null)
[ -n "$FILES" ] || fail "nothing downloaded — the link may have expired; copy it again from Get installer"
echo "$FILES" | while read -r n; do
  f="$DIR/$n"
  summary file "$n"; summary size_mb $(( $(wc -c < "$f") / 1048576 ))
  echo "signature:"; check_sig "$f" | sed 's/^/  /'
done

if [ "$OPEN" -eq 1 ]; then
  F=$(ls -1t "$DIR" | grep -Ei '\.(dmg|pkg|zip)$' | head -1)
  [ -n "$F" ] || fail "no macOS installer (.dmg/.pkg/.zip) among the downloads"
  open "$DIR/$F" && echo "opened $F — follow the installer, then start the launcher once and sign in"
fi
echo "RESULT: SUCCESS: downloaded to $DIR"
exit 0
