# Build Loader reference

Read when a run fails, when the user asks about an option, or before adding options to the scripts.

## Package

- `BuildLoader.zip` from PA. Windows: `Win\build_loader.exe`. macOS: `Mac/build_loader` + dylibs + Qt frameworks
  next to it (loaded via `@executable_path`) — keep the folder intact, unpack with `ditto -x -k` (keeps framework
  symlinks).
- macOS binary 1.23.0 is **x86_64 only** → Apple Silicon needs Rosetta (`softwareupdate --install-rosetta
  --agree-to-license`). Signed "Developer ID Application: Xsolla (USA), Inc (2FWGTXK3RK)"; remove quarantine with
  `xattr -dr com.apple.quarantine <dir>` if macOS blocks the dylibs.
- System requirements (docs): Windows 10 x64 or macOS 12.4+, 1.6 GHz CPU, 100 MB RAM, free disk 1.5 × build size.

## Platform of an uploaded build

The build's platform is **not** taken from its files: `libBuildLoader` has a compiled-in constant `platform` and calls
`/projects/<id>/builds?platform=<…>`. The Mac package creates macOS builds, the Windows package Windows builds
(confirmed: a Windows game uploaded with the Mac Build Loader appeared in the launcher as a macOS build). Upload each
OS's build from a computer with that OS. There is no option to override it in 1.23.0.

## Options

Documented: `--init`, `--update`, `--builds-list`, `--descr <text>`, `--api-key <key>`, `--game-path <path>`,
`--chunk-size <10mb..500mb>` (default 500mb), `--retry-timeout <10..60 s>` (default 20), `--retry-count <1..10>`
(default 3), `--set-build-on-test` (Draft), `--set-build-on-master` (Published; ignored if `--set-build-on-test` is
also given), `--no-progressbar`, `--ignore-file-path <json>`, `--use-ignore-file`.

Found in the 1.23.0 binary, not in the docs (ask the user / `--help` before relying on them): `--thread-count`
("default and maximum value is 5"), `--regions-list`, `--region-code`, `--region-name`, `--alternate-cdn`,
`--launcher-game-update`, `--xlauncher-logs`, `--help`.

Doc vs binary mismatches (the binary wins): the docs print options with an en dash (`–init`) — use `--`; the docs
write `-no-progressbar` — the binary uses Qt's parser, use `--no-progressbar`; the docs mention both
`--use-ignore-file` and `--use-ignore-files` — the binary has `--use-ignore-file`.

Limits from the binary: description ≤ 512 characters; `--game-path` must contain only Latin characters (docs).

## Output format (1.23.0)

```
Build loader version:   1.23.0
Current region:         default
Current game path:      "<path>"
Arguments: ...
--------------------------------------------------
Start Init
...
Finish Init. Result: success
--------------------------------------------------
```

The scripts take the last `Result: <word>` plus the exit code. "Default region already exists. Please use another
code and name…" during `--init` is informational.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Bad CPU type in executable` | Apple Silicon without Rosetta → install Rosetta |
| "cannot be opened", "damaged", dylib not loaded | quarantine or broken symlinks → `xattr -dr com.apple.quarantine`, re-unpack with `ditto` |
| `ERROR: API key is empty` | key not passed → `XSOLLA_BL_API_KEY` |
| init/update rejects the key, "specify a new API key … or contact Xsolla technical support" | wrong game's key or regenerated key → re-copy from that game's Builds › Game builds |
| `ERROR: Game path is empty` | `--game-path` missing and not remembered → pass it |
| path errors with spaces / Cyrillic | use the scripts' workdir (`~/xsolla_builds`, `C:\xsolla_builds`) |
| `Chunk size in MB should be between 10 and 500` / `Failed to parse --chunk-size` | value like `100mb` within range |
| `Description is too long` | ≤ 512 chars |
| `Can't open ignore json file` / `Ignore path is corrupted` | wrong path or invalid JSON; format `{"ignoring_files": [...]}` |
| upload stalls / network errors | rerun; the scripts pass `--retry-count` (≤10), `--retry-timeout` (≤60), `--chunk-size` (e.g. 100mb) through; try another network / VPN off |
| whole game re-downloads on every launcher update | files rewritten by the game are not in the ignore list |
| build not in the table yet | the table can lag a little behind exit 0 — refresh; check `--builds-list` |
