# Roadmap

1. Verify that a Wine 8+ x86_64 runtime actually runs on Intel macOS Monterey 12.x.
2. Build `AIMP Monterey.app` using the original AIMP v5.40.2727 Windows x64 portable package.
3. Test playback, sound output, Finder integration and playlist behavior on a physical Intel Mac.
4. Fix Wine-specific playlist drag-and-drop, CoreAudio, Cyrillic and window-focus defects if reproduced.
5. Add app icon and optional menu-bar / media-key bridge after baseline playback works.
6. Package a final DMG on a Mac and verify its checksum.

This is a **Wine-based compatibility wrapper**, not a source-code port of AIMP. A native port would require work on https://github.com/ArtemIzmaylov/ACL and access to AIMP application code.
