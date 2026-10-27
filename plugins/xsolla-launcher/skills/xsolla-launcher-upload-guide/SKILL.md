---
name: xsolla-launcher-upload-guide
description: Step-by-step guide that walks a person through uploading their game to Xsolla Player when Claude cannot run commands on their computer (claude.ai, Cowork, mobile) — one step per message, ready-to-run commands for their Mac (zsh) or Windows (PowerShell), a downloadable upload script, reading their output and fixing errors, then Player Account clicks up to a chosen stop point (by default one step before launcher generation; launcher download and testing only on request). Use whenever someone wants to upload, update or patch a game build in Xsolla Player / Player Account, mentions Build Loader, BuildLoader.zip, a launcher API key, Get installer, or "загрузить игру в лаунчер Xsolla", and you cannot run commands on their own Mac/PC (a cloud/Linux sandbox does not count). If your shell is their own computer (Claude Code), use the xsolla-launcher-upload skill instead.
---

# Xsolla Player upload — step-by-step mode

You cannot run anything on the user's computer, so you are their guide: **one step per message**, each with exactly
what to click or paste, what they should see, and what to send back. Wait for their reply before the next step.
Reply in the user's language. Keep each message short — a step, a command block, "send me the last lines".

Facts about Build Loader (options, output, errors) are in `references/build_loader.md`; the upload scripts are in
`scripts/`. Docs: developers.xsolla.com/distribute-game/launcher/.

## Rules that save the user pain

- **One step per message** = one thing for the user to do and one thing to send back. A file plus the commands that
  use it is one step (deliver them together). Default to short checklists; split further only if the user is lost.
- **macOS Terminal is zsh.** Never give bash-only syntax there (`read -p` fails with "no coprocess"). Secret prompt in
  zsh: `read -s "XSOLLA_BL_API_KEY?API key: "; export XSOLLA_BL_API_KEY`. Scripts are run with `bash script.sh`.
  The key lives only in that Terminal window: if they close it, the `read -s` line has to be run again.
- **Paths:** when the location is known, build it yourself (`"$HOME/Desktop/My Game.zip"` — quotes, `$HOME`, not `~`).
  Otherwise: type the command up to `--game ` and **drag the file from Finder into the window without quotes** —
  Terminal escapes spaces itself (`My\ Game.zip`); inside quotes those backslashes would break the path. Original
  archive names may contain spaces/Cyrillic — the script copies them to a safe Latin path, nothing to rename.
- **Downloaded files get renamed** (`bl_upload (1).sh`). Run scripts as
  `bash "$(ls -t ~/Downloads/bl_upload*.sh | head -1)" …` so the newest copy is used whatever its name.
- **The key is a secret.** It goes into the terminal prompt, not into chat or files. If they pasted it in chat, don't
  repeat it; mention once at the end that it can be regenerated in PA.
- **Never tell them to Publish** (build *Set as published*, launcher *Publish*) as part of testing — that reaches real
  players; it's their decision after testing.

## Stop point — how far to go (ask once if unclear; default `ready`)

| Stop point | Ends after | Use when |
|---|---|---|
| `check` | dry run: build unpacked, platform and start file detected — nothing uploaded | they want to see whether the build is fine first |
| `upload` | build uploaded to Draft, `RESULT: SUCCESS` | they will do the PA part themselves |
| **`ready`** (default) | upload + PA checklist up to **one step before Generate installer**: build row in Draft, Executable files filled in | normal case **today** |
| `launcher` | + Generate installer, Get installer, download/verify/install the launcher | only if the user explicitly asks for it |

Launcher **installer generation is currently unstable**, so by default stop at `ready`: end with "everything is ready
for Generate installer" and say in one line that generation is the next, separate step they can ask for later. If the
user says "до конца / including the launcher / до генерации включительно", use `launcher` and warn once that
generation may fail or take hours — then report what PA shows rather than retrying in a loop. Accept the stop point
in their words ("только проверь", "только загрузи", "до генерации") and name the chosen stop point in your first reply.

## Step 1 — What we're uploading (one message, ask only what's missing)

1. Computer OS: **macOS** or **Windows** (Linux: Build Loader doesn't exist for Linux — they need a Mac or PC).
2. Game for which OS: **macOS** (`.app`) or **Windows** (`.exe` + files). **The computer decides the platform**:
   Build Loader registers every build for the OS of the computer it runs on (the Mac Build Loader always creates
   macOS builds), so a Windows game must be uploaded from a Windows PC and a macOS game from a Mac. If their game's
   OS ≠ their computer's OS, say so before anything else and switch the plan to the right computer. Both OSes →
   two uploads, one from each computer (same key if the launcher has one game for both OSes).
3. Game name (just a label for the build description and local folder — it does not have to match PA; if they gave
   archive names, derive it and say so instead of asking) and where the archive/folder is.

## Step 2 — Player Account (they click)

1. PA → project → **Launcher** → **Edit launcher** → **Games**: the game exists? If not — add it.
2. Game → **Set up** → **Builds › Game builds**:
   - download **BuildLoader.zip** for **their computer's** OS (not the game's) into Downloads;
   - copy **API key (launcher ID)** — keep it at hand, don't paste it in chat if they can avoid it.

## Step 3 — Script + commands (one message)

Deliver `scripts/bl_upload.sh` (Mac) or `scripts/bl_upload.ps1` (Windows) as a downloadable file: in claude.ai /
Cowork copy it into the output folder with code execution and present it (file card / download link). Tell them to
save it to **Downloads**. It unpacks the game into a safe path, finds Build Loader in Downloads, fixes the `.app`
executable bit, checks Rosetta, runs `--init` + `--update` in Draft, masks the key in logs and ends with a `RESULT:`
line. If you cannot deliver files at all, use Step 4b instead.

In the same message, the commands:

**macOS (Terminal, zsh):**
```zsh
read -s "XSOLLA_BL_API_KEY?API key: "; export XSOLLA_BL_API_KEY; echo
```
```zsh
bash "$(ls -t ~/Downloads/bl_upload*.sh | head -1)" --game "$HOME/Desktop/<archive>.zip" --name "<Game name>"
```
(Two OSes: run this on the Mac with the macOS archive, and the Windows command below on a PC with the Windows archive.)

**Windows (PowerShell):**
```powershell
$env:XSOLLA_BL_API_KEY = Read-Host "API key"
```
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File (Get-ChildItem "$HOME\Downloads\bl_upload*.ps1" | Sort-Object LastWriteTime | Select-Object -Last 1).FullName -Game "<path to archive>" -Name "<Game name>"
```


For stop point `check`, add `--prepare-only` (`-PrepareOnly`) — nothing is uploaded, no key needed.

Tell them: the first upload sends the whole game (minutes for hundreds of MB, longer for GBs) and is quiet while
uploading; don't close the window. Ask for the lines from `SUMMARY platform=` to `RESULT:`.

## Step 4 — Read their output

- `RESULT: SUCCESS` → Step 5, using the start file names from `SUMMARY executable_macos=` / `executable_windows=`.
- `RESULT: FAILED: …` → match the message and log tail against the troubleshooting table in
  `references/build_loader.md`; give **one** fix and the same run command again (with the `read -s` line if they
  may have closed the window). Typical:
  - network / retry errors → rerun with `--retry-count 10 --retry-timeout 60 --chunk-size 100mb`
    (`-RetryCount 10 -RetryTimeout 60 -ChunkSize 100mb`), suggest another network / VPN off;
  - `Build Loader not found` → BuildLoader.zip for their computer's OS is not in Downloads/Desktop (Step 2);
  - Rosetta message (Apple Silicon) → `softwareupdate --install-rosetta --agree-to-license`, then rerun;
  - "cannot be opened" / Gatekeeper → System Settings → Privacy & Security → Open Anyway, then rerun;
  - `REASON: this is a win build, but this computer uploads mac builds` (or the reverse) → this archive must be
    uploaded from a computer with the game's OS; no workaround;
  - `you chose --platform …, but the build looks like …` → clarify which archive is for which OS;
  - key rejected → copy the key of *this* game again (each game has its own).

## Step 4b — Manual path (no script)

Only if they can't get the script. Same idea, plain Build Loader (paths without spaces/Cyrillic):

macOS:
```zsh
mkdir -p ~/xsolla_builds/bl ~/xsolla_builds/game && ditto -x -k ~/Downloads/<BuildLoader zip> ~/xsolla_builds/bl && xattr -dr com.apple.quarantine ~/xsolla_builds/bl
```
```zsh
ditto -x -k "<game archive>" ~/xsolla_builds/game && ls ~/xsolla_builds/game
```
(if `ls` shows one wrapper folder that is not `.app`, use that folder as the game path below; for a `.app`:
`chmod +x ~/xsolla_builds/game/*.app/Contents/MacOS/*`)
```zsh
~/xsolla_builds/bl/Mac/build_loader --init --api-key "$XSOLLA_BL_API_KEY" --game-path ~/xsolla_builds/game
```
```zsh
~/xsolla_builds/bl/Mac/build_loader --update --game-path ~/xsolla_builds/game --descr "<Game name> v1" --set-build-on-test --no-progressbar
```
Windows: `Expand-Archive` both zips into `C:\xsolla_builds\bl` and `C:\xsolla_builds\game`, then
`C:\xsolla_builds\bl\Win\build_loader.exe --init --api-key $env:XSOLLA_BL_API_KEY --game-path C:\xsolla_builds\game`
and `… --update --game-path C:\xsolla_builds\game --descr "<Game name> v1" --set-build-on-test --no-progressbar`.
Success looks like `Finish … Result: success`. Apple Silicon "Bad CPU type" → Rosetta:
`softwareupdate --install-rosetta --agree-to-license`.

## Step 5 — Player Account after the upload (one short checklist)

1. Builds › Game builds: a row with their description, **Branch** = draft (also under *Branches*); the table can lag
   a minute — refresh.
2. **Executable files**: for each OS the start file exactly as reported in `SUMMARY executable_macos=` /
   `executable_windows=`.
3. Stop point `ready` (default): ask them to confirm 1–2 and finish — "the build is in Draft and configured; the next
   step is **Generate installer** (Launcher → Edit launcher → Settings → Launcher build → Generate in *Draft*). It's
   unstable right now, so we stop here — come back when you want to do it."
   Stop point `launcher`: they click **Generate** (can take hours and currently may fail — if it does, note what PA
   shows and stop; Windows gets web + standalone installers, macOS standalone only) and go on to Step 6.

## Step 6 — Launcher build: download and test (stop point `launcher` only)

When generation is done: *Draft* → **Get installer**. Easiest: click the link in the browser and run the installer.
If you delivered `scripts/get_launcher.sh` / `.ps1`, they can instead run
`bash "$(ls -t ~/Downloads/get_launcher*.sh | head -1)" --url "<link>" --open` (Mac) or
`powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\Downloads\get_launcher.ps1" -Url "<link>" -Open`
(Windows) — it also prints the installer's signature (should be Xsolla's).

Then: open the launcher, sign in, install the game, press Play. If the game doesn't start on macOS, the usual cause is
a missing executable bit (zip made on Windows) — re-upload with the script, which fixes it.

## Next version

Same run command with the new archive and the same name → only a patch is uploaded → in the launcher **Update**.
Publish (build *Set as published*, launcher *Publish*) only when they decide testing is done.
