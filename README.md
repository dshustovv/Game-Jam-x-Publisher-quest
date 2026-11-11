# Game Jam x Publisher quest

Quest for Game Jam participants: get a jam build into Xsolla Player (Draft) with Claude Code.

> `src/` and `xsolla-upload.zip` hold the standalone upload app (`Xsolla Upload.command` / `.bat`). It is kept for reference and is no longer part of the quest page.

## Quest page

`index.html` is the quest landing (Stage 0 registration, then upload with Claude Code). Open it locally or serve it with GitHub Pages: https://dshustovv.github.io/Game-Jam-x-Publisher-quest/

## How participants upload
Download `xsolla-launcher-upload.zip`, drag the file into the Claude Code input line (do not unzip it) and follow Claude's instructions.

The skill does not print a receipt: Claude reports the result in chat and participants tick the quest steps by hand.

The plugin lives in `plugins/xsolla-launcher/`, the marketplace file in `.claude-plugin/marketplace.json`.

## extras/
- `extras/xsolla-player-prototype/` — прототип вкладок Game Jam и Jam rewards для Xsolla Player (GitHub Pages: `/extras/xsolla-player-prototype/`).
- `extras/cover/` — обложка квеста.

## Adding a skill in the Claude app (Customize → Skills)
The Claude app accepts one skill per zip (one top-level folder with one `SKILL.md`). The quest uses only the first one; the guide is not part of the quest for now:
- `xsolla-launcher-upload.zip` (runs the upload for you, needs Claude Code or another place where Claude can run commands on your computer)
- `xsolla-launcher-upload-guide.zip` (step-by-step guide for the Claude app, Cowork and mobile, where Claude cannot run commands)

`xsolla-skills.zip` holds both skills together and is only for unzipping into `~/.claude/skills` for Claude Code.
