# Game Jam x Publisher quest

Upload helper for the Game Jam quest: `xsolla-upload.zip` (Mac: `Xsolla Upload.command`, Windows: `Xsolla Upload.bat`, needs Python 3).
The app uploads your build to Draft through Build Loader and prints a receipt that the quest page verifies.

Download: https://github.com/dshustov-xslplayer/game-jam-x-publisher-quest/releases/latest/download/xsolla-upload.zip

`src/` holds the unzipped files for review.

## Quest page

`index.html` is the quest landing (Stage 0 registration, upload app, receipt check). Open it locally or serve it with GitHub Pages: https://dshustov-xslplayer.github.io/Game-Jam-x-Publisher-quest/

## Three ways to upload

1. **Claude Code plugin** (needs Claude Code). In Claude Code run:
   ```
   /plugin marketplace add dshustov-xslplayer/Game-Jam-x-Publisher-quest
   /plugin install xsolla-launcher@xsolla-launcher-tools
   ```
   For a step-by-step walkthrough use `/upload-guide`.
   Then `/upload-game "<game file or folder>" "<Game name>" [mac|win|both] [check|upload|ready|launcher]`.
   Set the API key as an environment variable (`XSOLLA_BL_API_KEY`) before starting Claude Code; do not paste it into the chat.
2. **App**: `xsolla-upload.zip` (see above). The only path that prints a receipt for the quest page.
3. **Claude Code skills**: `xsolla-skills.zip` holds `xsolla-launcher-upload` and `xsolla-launcher-upload-guide`.
   Unzip into `~/.claude/skills` (Windows: `%USERPROFILE%\.claude\skills`) and run `/xsolla-launcher-upload`.

The plugin lives in `plugins/xsolla-launcher/`, the marketplace file in `.claude-plugin/marketplace.json`.
