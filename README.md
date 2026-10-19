# AIMP Monterey — Intel Mac / macOS 12

> **Experimental:** Automated packaging is configured, but playback has **not** yet been verified on a physical Intel Mac running Monterey. This is a compatibility wrapper, **not a native AIMP port**, and a successful GitHub Actions build alone is not proof of compatibility.

## One-click target

`AIMP Monterey.app`, bundled with the WineHQ x86_64 runtime and the required GStreamer framework, launched from Finder. **No Homebrew, MacPorts, Wine installer, Terminal, or administrative privileges required on the target Mac.**

**First start requires internet access:** the app downloads the **unaltered original 64-bit portable AIMP** from [aimp.ru](https://aimp.ru/?do=download&os=windows), verifies the ZIP structure / Windows x64 executable, and extracts it into the current user's Application Support folder. Later starts work offline. It never publishes altered AIMP files.

The user-facing experience is intended to be: download DMG → drag app to Applications → open AIMP normally. However, due to **Gatekeeper**, an unnotarized/ad-hoc-signed app may be blocked or require explicit first-run approval. A truly normal launch without security prompts requires **Apple Developer ID signing and notarization**, which are not set up here.

## Downloading a CI package

After the experimental workflow succeeds, open the [GitHub Actions page](https://github.com/MusMat17/AIMP-Monterey/actions/workflows/standalone-dmg.yml), select a successful run, and download artifact **AIMP-Monterey-Intel-Standalone-UNTESTED**. GitHub may require sign-in to download build artifacts.

**Do not regard this as a release yet.** A DMG is produced only when CI successfully downloads a compatible Wine x86_64 runtime, extracts GStreamer, compiles an Intel launcher with minimum macOS 12.0, passes ad-hoc signing and verifies its bundle. Runtime testing on Monterey is still mandatory.

## How the package is built

The workflow uses the `macos-15-intel` GitHub-hosted runner (macOS 12 runners no longer exist). It executes:

```bash
bash scripts/build-standalone.sh
```

It fetches these third-party components at build time:
- WineHQ x86_64 [11.0_1](https://github.com/Gcenx/macOS_Wine_builds/releases/tag/11.0_1)
- [GStreamer runtime 1.28.6](https://gstreamer.freedesktop.org/data/pkg/osx/1.28.6/) (download SHA256 verified)
- The launcher sources in this repository.

*The original AIMP files are **not bundled** in the public DMG.* The app downloads from the official source at first launch. See the [official AIMP license](https://aimp.ru/?do=eula&os=desktop).

For local Mac builds, `scripts/build-standalone.sh` needs Apple's Xcode Command Line Tools or Xcode. **End users do not need development tools.**

## Installation state and logs

- Wine prefix: `~/Library/Application Support/AIMP Monterey/prefix`
- Original AIMP application files: `~/Library/Application Support/AIMP Monterey/AIMP`
- Diagnostic log: `~/Library/Logs/AIMP Monterey/launcher.log`

The old `scripts/build-monterey.sh` is preserved for reference but produced a non-standalone wrapper dependent on installed Wine. **Use `build-standalone.sh` and its CI workflow instead.**

## Validation checklist

- [ ] GitHub Actions full Wine+GStreamer DMG build succeeds.
- [ ] Boot successfully on a **real Intel macOS Monterey 12.x** machine.
- [ ] Gatekeeper behavior documented / Developer ID notarization implemented.
- [ ] Original AIMP archive downloaded and SHA256 recorded in logs.
- [ ] 44.1 kHz and 48 kHz audio playback on CoreAudio (MP3/FLAC/WAV).
- [ ] Track import / playlists / Cyrillic filenames / UI.
- [ ] Sleep and wake; change audio devices during playback.
- [ ] Finder file opening and multimedia keys (latter not implemented).

**Current project status: one-click build pipeline created, working release NOT yet confirmed.**
