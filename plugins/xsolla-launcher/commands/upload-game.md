---
description: Upload a game to Xsolla Player — archive/folder/.dmg/.exe, game name and API key; choose platform and how far to go
argument-hint: <game file(s)> "<Game name>" [API key] [mac|win|both] [check|upload|ready|launcher]
allowed-tools: Bash, Read, Glob, Grep, Task, Skill
---

Upload a game build to Xsolla Player. Arguments from the user: `$ARGUMENTS`

1. **Parse** the arguments, in any order:
   - game input(s): paths to `.zip .7z .rar .tar.gz .dmg`, a folder, a `.app`, or an `.exe` / `.msi`
     (dragged-in paths may contain `\ ` escapes — unescape them);
   - the game name (quoted text that is not a path);
   - the API key (a long token of letters and digits, ~32 chars);
   - platform: `mac`, `win`, `both` (also "macOS", "Windows", "обе");
   - stop point: `check`, `upload`, `ready`, `launcher` (also "только проверь", "только загрузи",
     "до генерации", "до конца"). Default **`ready`** — one step before launcher generation, which is unstable now.

2. **Ask once** (one message) for whatever is still missing:
   - no game input → ask for the file;
   - no key and stop point is not `check` → point to Player Account → Launcher → Edit launcher → Games →
     Set up → Builds › Game builds → API key;
   - the game is for a different OS than this computer → say first that Build Loader uploads a build as the OS of
     the computer it runs on, so it has to be uploaded from a <Windows PC|Mac>; don't delegate;
   - two inputs → only this computer's part is uploaded here; the other is uploaded the same way from the other OS;
   - the name, only if it can't be taken from the file name.
   State the chosen stop point in that message (or in your first line if nothing is missing).

3. **Delegate** to the `game-uploader` subagent with all values spelled out (inputs, name, key, platform,
   stop point). It runs Build Loader on this computer and returns a fixed summary.

4. **Show the user** its summary: result, platform and start files, the build description, and the Player
   Account checklist up to the stop point. If it returned `NEEDS INPUT` (e.g. 7-Zip or innoextract missing, an
   installer that must be installed first), ask the user that one question; if they agree to install a tool, run the
   install command it gave, then delegate again.

5. If the API key was typed in this chat, end with one line: the key can be regenerated in Player Account after
   testing. Never set builds to Published and never press Publish for the launcher.
