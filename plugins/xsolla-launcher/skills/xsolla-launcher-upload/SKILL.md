---
name: xsolla-launcher-upload
description: Upload a game build to Xsolla Player for the user, end-to-end, from their own terminal (Claude Code) — take their game archive (macOS .app, Windows .exe build, or both), game name and launcher API key; find and run Build Loader, put the build in Draft and bring them to one step before launcher generation (configurable stop point — check, upload, ready or launcher — launcher download and install only on request), telling them exactly what to click in Player Account. Use whenever someone wants to upload, deliver, patch or update a game in Xsolla Player / Player Account, mentions Build Loader, build_loader, BuildLoader.zip, a launcher API key or "launcher ID", Get installer / launcher build, or writes "загрузи игру в лаунчер Xsolla" — even if they only drop an archive and a key. Without terminal access on the user's machine (claude.ai, Cowork) switch to the step-by-step guide in references/guide_mode.md.
---

# Xsolla Player Uploader: upload a game build

The user gives you **the game archive, the game name and the API key**. You do everything else on their machine
and hand back a short list of clicks in Player Account (PA). They should not have to type commands. Reply in the
user's language.

Sources: Xsolla docs (developers.xsolla.com/distribute-game/launcher/: Upload game build, Binary patching, List of
ignored files, Generate installer, Deep links, In-game user authentication, Maintenance) and behaviour observed with
Build Loader **1.23.0** — details in `references/build_loader.md`.

## 0. Can you run commands on the user's computer?

Build Loader is a native macOS/Windows program; it must run on the user's machine. Check `uname -s`
(`Darwin` = macOS, `MINGW*/MSYS*` or PowerShell available = Windows).

- **Your shell is the user's Mac/PC (Claude Code CLI or desktop)** → follow this file.
- **Your shell is a Linux sandbox (claude.ai, Cowork) or you have no shell** → you cannot upload for them. Say so in
  one sentence and continue with **`references/guide_mode.md`** (step-by-step mode: you hand them one script and one
  command at a time and read their output). Don't improvise long command lists.

## 1. Inputs — ask only for what is missing, in one message

| Input | Notes |
|---|---|
| Game build | `.zip`, `.7z`, `.rar`, `.tar(.gz)`, `.dmg`, a folder, a `.app`, a portable single `.exe`, or a Windows **installer** `.exe`/`.msi`. For a two-OS release: one input per OS. If they give only a file name, find it: `find ~/Desktop ~/Downloads ~/Documents -maxdepth 3 -iname '<name>*'` (Spotlight `mdfind` misses unindexed folders) |
| Game name | used in the build description and work folder |
| **API key** | Sign in at https://xsolla.com/for/free-to-play-pc/account/login, then PA → project → **Launcher** → **Edit launcher** → **Games** → **Set up** next to the game → **Builds › Game builds** → **API key (launcher ID)**. One key per game in PA; if the game does not exist yet they add it first (Edit launcher → Games) |

**Input formats** — the script handles them and reports `SUMMARY input_format=`:
- `.zip`, `.tar*` — built in. `.dmg` — mounted with `hdiutil` on macOS (the `.app` and files next to it are copied,
  the *Applications* shortcut skipped); on Windows only via 7-Zip, and a Mac upload is better anyway.
- `.7z` / `.rar` — need an extractor: macOS tries `7zz`/`7z`, Build Loader's own `7zr` (7z only), `unar`, then the
  system `tar` (libarchive); Windows tries 7-Zip, then `tar.exe`. On `REASON: no … extractor` offer to install one
  (`brew install sevenzip` / `brew install unar`, `winget install 7zip.7zip`) — ask before installing anything.
- `.exe` — a portable single-file game is uploaded as is. An **installer** (Inno Setup, NSIS, MSI, WiX,
  InstallShield; detected from the file) is not the game: the script unpacks NSIS/MSI with 7-Zip and Inno with
  `innoextract`; if that's impossible it stops — then ask the user to install the game and give you the installed
  folder (usually the cleaner option anyway, since unpacked installers can miss files the installer generates).

**The computer decides the platform — this is the rule users trip over.** Build Loader stamps every build with the
OS it was compiled for (a constant inside the program, sent to the API as `?platform=…`): the **Mac** Build Loader
always creates **macOS** builds, the **Windows** one **Windows** builds — whatever files are inside. A Windows game
uploaded from a Mac shows up in the launcher as a macOS build (seen in practice). So:
- **macOS build → upload from a Mac; Windows build → upload from a Windows PC** (or a Windows VM / CI runner);
- the scripts refuse a build for the other OS (`REASON: this is a win build, but this computer uploads mac builds`,
  exit 2) — tell the user which computer to use; don't look for workarounds;
- `--game-mac … --game-win …` uploads **only this computer's part** and reports the other as
  `SUMMARY pending=…` — tell the user to run the same request on a computer with the other OS, with the **same key**
  if the launcher has one game for both OSes, or that game's key if each OS is a separate game;
- the script detects the build's OS from its root (`.app` → macOS, `.exe` → Windows); ask only if what the user said
  contradicts the files (`you chose --platform …, but the build looks like …`).

**Build Loader** (the one for *this computer's* OS — which is also the build's OS) is found automatically (unpacked copy in `~/xsolla_builds/_build_loader`, else `*build*loader*.zip`
in Downloads/Desktop). Only if the script says `Build Loader not found`, ask them to download **BuildLoader.zip** for
their computer's OS on the same PA page (**Builds › Game builds**) into Downloads, then rerun.

**The key is a secret.** Pass it only via the `XSOLLA_BL_API_KEY` environment variable of the command; never write it
to files or repeat it in full (logs mask it as `ABCD…XYZ`). If it was pasted in chat, say once at the end that it
can be regenerated in PA after testing.

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

Run steps 2–4 back to back without checking in (stop earlier for `check` / `upload`); stop only for the cases in step 2 or a failure you can't fix.

## 2. Dry run

Installed as the `xsolla-launcher` plugin, the same scripts are on `PATH` as `xsolla-upload` (flags as below, works on
macOS and Windows/Git Bash) and `xsolla-get-launcher`; otherwise call `<skill-dir>/scripts/…` directly.

```bash
bash "<skill-dir>/scripts/bl_upload.sh" --game "<archive>" --name "<Game name>" --prepare-only
```
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\bl_upload.ps1" -Game "<archive>" -Name "<Game name>" -PrepareOnly
```
(two OSes: `--game-mac "<mac archive>" --game-win "<win archive>"` / `-GameMac … -GameWin …`; force a platform with
`--platform mac|win` / `-Platform`.)

It unpacks into a stable Latin-only path (`~/xsolla_builds/<slug>/build`, `C:\xsolla_builds\<slug>\build`), drops
`__MACOSX`/`.DS_Store`, lifts a single wrapper folder, restores the executable bit of `.app` binaries (zips made on
Windows lose it and the game would not start), checks disk space (Build Loader needs 1.5 × build size) and prints
`SUMMARY platform=`, `executable_macos=`, `executable_windows=`. With exactly one start file per target OS, mention it
in one line and continue. Stop and ask only if there is no start file in the root, several candidates for one OS,
or a platform mismatch / file conflict between the two OS builds.

## 3. Upload (in the background)

```bash
XSOLLA_BL_API_KEY='<key>' bash "<skill-dir>/scripts/bl_upload.sh" --game "<archive>" --name "<Game name>"
```
```powershell
$env:XSOLLA_BL_API_KEY='<key>'; powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\bl_upload.ps1" -Game "<archive>" -Name "<Game name>"
```

- Uploads outlast normal command timeouts: run in the background, redirect output to a file, poll
  `<log_dir>/update.raw` (live Build Loader output; becomes masked `update.log` at the end) every 30–60 s and give
  short progress notes. `log_dir` is in the first `SUMMARY` lines.
- `--init` runs before every `--update`: Build Loader keeps one global config and keys are per game.
- Stage is **Draft** (`--set-build-on-test`) — testers only. There is deliberately no option for Published.
- A new version of the same game goes into the same build folder, so Build Loader sends a **binary patch**.
- Ignore list for files the game rewrites (saves, settings) — otherwise the launcher re-downloads the whole game:
  `{"ignoring_files": ["saves/profile.dat", "settings.ini"]}` → `--ignore <json>` / `-Ignore <json>`.

## 4. Read the result

Last line `RESULT: SUCCESS|FAILED: …`; before it `SUMMARY init_result`, `update_exit`, `update_result`,
`update_seconds`, `build_size_mb`. On failure read the log and use the troubleshooting table in
`references/build_loader.md`; fix local causes (path, Rosetta, quarantine, disk) and rerun; network/retry errors →
rerun with `--retry-count 10 --retry-timeout 60 --chunk-size 100mb` (`-RetryCount/-RetryTimeout/-ChunkSize`); for key errors ask for
the key of *this* game again. "Default region already exists…" during init is harmless noise.

## 5. Clicks in PA — up to the stop point, with their real values

For stop point `ready` (default), a short checklist that ends right before generation:

1. **Check**: game → Set up → Builds › Game builds → row `<descr>`, column **Branch** = draft; also listed under
   *Branches* (the table can lag a minute — refresh). After `--stage none`: pencil → **Set as draft** → confirm → Close.
2. **Executable files** tab: per OS the start file exactly as in `SUMMARY executable_macos=` / `executable_windows=`
   (e.g. `Sherwood Legend 2.app`, `Game.exe`). Redistributables (VC++ etc.) → *Redistributables* tab.
3. Ask them to confirm both, then finish: "The build is in Draft and configured — the next step is **Generate
   installer** (Launcher → Edit launcher → Settings → Launcher build → Generate in *Draft*). It's unstable right now,
   so we stop here; ask me when you want to do it."

Only for stop point `launcher` continue with:

4. **Generate installer** (once; again after changing launcher name, icon or OS list): Launcher → Edit launcher →
   Settings → **Launcher build** → **Generate** in *Draft*. May take hours and currently may fail — if it does, report
   what PA shows and stop; nothing on the user's side fixes it. Windows: web + standalone, macOS: standalone only.
5. When it's ready: **Get installer** in *Draft* → ask them to paste the link(s) here (step 6).

Always: **Publish** only after testing — build: pencil → **Set as published**; launcher: **Publish** in *Draft*. Both
reach real players: say so plainly; never do or script it.

## 6. Launcher build: download, check, install (stop point `launcher` only)

```bash
bash "<skill-dir>/scripts/get_launcher.sh" --url "<link>" [--url "<link2>"] --open
```
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\get_launcher.ps1" -Url "<link>","<link2>" -Open
```

Downloads into `~/xsolla_builds/_launcher/<time>/`, prints size and signature (macOS: `codesign`/`spctl`/`pkgutil`;
Windows: Authenticode — expect a valid Xsolla signature, report anything else) and with `--open` starts the
installer. Windows web installer needs internet; the standalone one works offline. Then the user signs in to the
launcher once and installs the game. Download only links the user pasted from PA.

Optional checks once the launcher has been opened once (launcher-id and game-id from the PA URL Edit launcher →
Content → Tabs → Edit: `…/new-launcher/<launcher-id>/game/<game-id>/tabs/<tab-id>`):
`xl-<launcher-id>://game/<game-id>?action=install&force=1&path=<dir>`, `?action=update`, `?action=repair`,
`?action=start`, `?action=uninstall` (macOS `open "<link>"`, Windows `Start-Process "<link>"`). The launcher starts the
game with `--xsolla-login-token <JWT>` and `--xsolla-locale <locale>`.

## Rollback / removal

The docs only describe stages for builds, not deletion. A Draft build is invisible to players, so rollback = make
the previous good build Published (pencil → Set as published) or leave the unwanted one in Draft. For deletion check
the row's pencil/actions menu; otherwise Xsolla support / CSM (csm@xsolla.com). Deleting `~/xsolla_builds/<slug>`
locally makes the next upload a full one.

## API key handling
- The scripts mask the key in every log they write (on macOS the output is masked while it streams, so no unmasked copy is left on disk). On Windows the log is masked when the upload ends.
- Build Loader only accepts the key as the `--api-key` argument, so another program on the same computer can see it in the process list while the upload runs. Treat the computer as trusted and rotate the key in Player Account if you shared the machine.
- On Windows the key must not contain a space or any of `% " ^ & | < >`. The script stops with a clear message if it does.
