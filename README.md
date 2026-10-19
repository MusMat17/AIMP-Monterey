# AIMP Monterey — Intel / macOS 12

**Status: source preview, not a tested DMG release.**

This repository prepares a macOS `.app` launcher for the **original AIMP 5.40.2727 Windows x64 portable build** using **a separately installed Wine runtime**, and packages the launcher into a `.dmg` on an Intel Mac. It is **not a native port** and does **not ship Wine** or AIMP binaries.

## Requirements

- Intel x86_64 Mac, macOS Monterey 12.x.
- A Wine 8+ distribution compatible with Intel macOS 12 and accessible as `wine` (Wine compatibility on this machine must be verified separately; several modern wrappers now require newer macOS).
- Original, unmodified AIMP x64 portable ZIP, obtained from [the official site](https://aimp.ru/?do=download&os=desktop). The builder attempts the official download endpoint `https://aimp.ru/?do=download.file&id=31`. If that endpoint changes, put the ZIP at `vendor/AIMP-portable-original.zip`, or its unpacked content at `vendor/AIMP/` (with `AIMP.exe` in that directory).

## Build on an Intel Mac

```bash
chmod +x scripts/*.sh app/AIMP-launcher.sh
./scripts/diagnose-monterey.sh
./scripts/build-monterey.sh
```

Successful **macOS** build output (local, not included in Git):

```
dist/AIMP Monterey.app
dist/AIMP-Monterey-Intel-12.dmg
dist/AIMP-Monterey-Intel-12.dmg.sha256
dist/AIMP-exe.sha256
```

Install the `.app` from the DMG in `/Applications`. It will create a dedicated `WINEPREFIX` at `~/Library/Application Support/AIMP Monterey/prefix`. Logs: `~/Library/Logs/AIMP Monterey/launcher.log`. Override the executable with `AIMP_WINE_BIN=/path/to/wine` when starting from Terminal.

**This DMG is not a self-contained distribution**: to run AIMP, compatible Wine must already be installed. Finder associations, sound, playback and integration are *not yet tested on Intel Monterey*.

## Testing targets

- [ ] Start in Finder, Gatekeeper behavior.
- [ ] CoreAudio: MP3, FLAC and WAV.
- [ ] Finder Open With, Cyrillic file paths.
- [ ] Playlist add/reorder, fonts, lyrics and visualizer.
- [ ] Sleep/wake, audio-device changes, quit behavior.
- [ ] Media keys and Dock integration (not implemented).

## Licensing / security

AIMP is proprietary © Artem Izmaylov. This project contains **only wrapper/build source code**: no executable AIMP files and no Wine runtime. Do not redistribute modified AIMP binaries without permission. Only download original AIMP files from its official website. The bundle is ad-hoc signed at most, **not notarized**. Do not disable macOS Gatekeeper globally.

See [project roadmap](docs/PLAN.md), [AIMP Component Library](https://github.com/ArtemIzmaylov/ACL), and the [older Monterey wrapper discussion](https://aimp.ru/forum/index.php?topic=42082.120).
