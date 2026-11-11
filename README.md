# Game Jam x Publisher quest

Quest for Game Jam participants: get a jam build into Xsolla Player (Draft) with Claude Code.

> `src/` and `xsolla-upload.zip` hold the standalone upload app (`Xsolla Upload.command` / `.bat`). It is kept for reference and is no longer part of the quest page.

## Quest page

`index.html` is the quest landing (Stage 0 registration, then upload with Claude Code). Open it locally or serve it with GitHub Pages: https://dshustovv.github.io/Game-Jam-x-Publisher-quest/

## Two ways to upload

1. **Claude Code plugin** (needs Claude Code). In Claude Code run these two commands one at a time (wait for the first to finish):
   ```
   /plugin marketplace add dshustovv/Game-Jam-x-Publisher-quest
   ```
   ```
   /plugin install xsolla-launcher@xsolla-launcher-tools
   ```
   For a step-by-step walkthrough use `/xsolla-launcher-upload-guide`.
   Then run `/xsolla-launcher-upload` and give Claude the game file or folder, the game name and the API key.
2. **Claude Code skills**: `xsolla-skills.zip` holds `xsolla-launcher-upload` and `xsolla-launcher-upload-guide`.
   Unzip into `~/.claude/skills` (Windows: `%USERPROFILE%\.claude\skills`) and run `/xsolla-launcher-upload`.

Neither path prints a receipt: Claude reports the result in chat and participants tick the quest steps by hand.

The plugin lives in `plugins/xsolla-launcher/`, the marketplace file in `.claude-plugin/marketplace.json`.

## extras/
- `extras/xsolla-player-prototype/` — прототип вкладок Game Jam и Jam rewards для Xsolla Player (GitHub Pages: `/extras/xsolla-player-prototype/`).
- `extras/cover/` — обложка квеста.

## Adding a skill in the Claude app (Customize → Skills)
The Claude app accepts one skill per zip (one top-level folder with one `SKILL.md`). Upload them one at a time:
- `xsolla-launcher-upload.zip` (runs the upload for you, needs Claude Code or another place where Claude can run commands on your computer)
- `xsolla-launcher-upload-guide.zip` (step-by-step guide for the Claude app, Cowork and mobile, where Claude cannot run commands)

`xsolla-skills.zip` holds both skills together and is only for unzipping into `~/.claude/skills` for Claude Code.
