# Cap

A menu-bar screenshot tool for macOS. [中文版](README.md) · Design: [`DESIGN.md`](DESIGN.md) · Implementation log: [`.scratch/cap-v1/`](.scratch/cap-v1/)

## Build & test

```bash
xcodebuild -project Cap.xcodeproj -scheme Cap -configuration Debug build
xcodebuild test -project Cap.xcodeproj -scheme Cap -destination 'platform=macOS'
```

## Signing & install

This machine signs with a local self-signed identity so TCC permissions survive rebuilds:

```bash
Scripts/make-signing-identity.sh
Scripts/install.sh
```

After the first launch, enable Cap under **System Settings → Privacy & Security → Screen & System Audio Recording**.

## Features

- **⌘⇧2 Capture**: drag a region / click a window / press Enter for full screen; each display can be selected independently
- **Editor**: frozen panel with an in-place toolbar and 9 tools (rectangle, arrow, line, text, pen, highlight, mosaic, number, crop), undo/redo, Chinese IME support
- **Output**: Enter copies the annotated image, ⌘S saves to `~/Pictures/Screenshots/`, Esc keeps the original
- **Menu-bar popover**: permission status, 8 recent screenshots (click to copy), open the history window, settings
- **History window**: grid of all screenshots, double-click to preview, copy, show in Finder, delete, clear
- **Settings**: save folder, PNG/JPEG format, launch at login, **custom global shortcuts** (capture / scroll capture / pin click-through; click to record, ⌫ restores defaults, Esc cancels); history capped at 100 items (oldest removed first)
- **Scrolling capture (v1.1)**: ⌘⇧7 select a scrollable area, auto-scroll and stitch into one long image; Esc aborts
- **OCR (v1.1)**: right-click → *Recognize Text* in the history window; on-device Vision recognizes Chinese and English and copies the text
- **Pinned screenshots (v1.1)**: ⌘T in the editor or right-click → *Pin to Screen* keeps a screenshot in a floating window; drag to move, scroll to zoom, double-click to reset, Esc to close, right-click to copy or click through; ⌥⌘P toggles click-through for all pins
- **Localization (v1.1)**: Simplified Chinese / English / Traditional Chinese, following the system language

## Default shortcuts

| Action | Default | Notes |
|---|---|---|
| Capture | ⌘⇧2 | Drag a region / click a window / Enter for full screen |
| Scrolling capture | ⌘⇧7 | Select a scrollable area, auto-scroll and stitch; Esc aborts |
| Toggle pin click-through | ⌥⌘P | Switch all pinned windows between interactive and click-through |

All three can be recorded in menu-bar popover → Settings → Shortcuts (⌫ restores defaults, Esc cancels).

## Permissions

- Screen recording: required for capture
- Accessibility: required for scrolling capture to scroll the target app (System Settings → Privacy & Security → Accessibility)

## Data locations

- History: `~/Library/Application Support/Cap/History/` (`index.json` + `images/` + `thumbs/`)
- Saved files: default `~/Pictures/Screenshots/`, configurable from the menu-bar popover

## Supported Macs

- The installed build is a **Universal binary**: runs on both Apple Silicon (arm64) and Intel (x86_64).
  ```bash
  lipo -info /Applications/Cap.app/Contents/MacOS/Cap
  # x86_64 arm64
  ```
- Minimum OS: **macOS 15.2** (see `DESIGN.md` §11). Intel Macs must support macOS Sequoia 15.2:
  - MacBook Pro 2018 and later (including 16-inch 2019), MacBook Air (2020 Intel)
  - iMac 2019 and later, iMac Pro 2017, Mac mini 2018, Mac Pro 2019
  - Older Intel Macs (Ventura/Sonoma or earlier) are not supported in v1
- Debug builds compile only the host architecture (`ONLY_ACTIVE_ARCH=YES`); **Release / `Scripts/install.sh` output is Universal**.
- The `Cap Local Signing` identity is trusted only on this machine. Copying the app to another Mac (including Intel) requires re-signing and re-granting screen recording permission; distributing it to others requires a proper Developer ID signature and notarization.

## Project layout

```text
Cap/
  App/            AppDelegate, entry point
  MenuBar/        NSStatusItem, popover, history window
  Capture/        ScreenCaptureKit capture, window index
  Selection/      Multi-display selection overlay
  Editor/         Frozen panel, annotation model & rendering, toolbar, canvas input, text input
  Scroll/         Scrolling capture (frame capture, auto-scroll, stitching)
  Pin/            Pinned screenshot windows
  OCR/            Vision text recognition
  Output/         Clipboard, PNG/JPEG encoding and saving
  History/        History index, thumbnails, pruning
  Settings/       UserDefaults settings, launch at login, shortcut recorder
  Resources/      Info.plist, AppIcon, Localizable.xcstrings
Scripts/          Signing identity, install, icon generation
CapTests/         Swift Testing unit tests (models / algorithms / rendering / settings)
```

## Troubleshooting

- **⌘⇧2 does nothing**: make sure `/Applications/Cap.app` is running. If the permission was revoked, the menu-bar icon turns into an orange exclamation mark; open the popover and follow the prompt to re-authorize.
- **Scrolling capture asks for Accessibility permission**: System Settings → Privacy & Security → Accessibility, enable Cap (on macOS 27 the first grant requires an admin password).
- **Permissions break after a rebuild**: install with `Scripts/install.sh` (stable self-signed `Cap Local Signing` identity); do not rebuild with ad-hoc signing.
- **Build errors like `unable to find xcodebuild` or SDK not found**: the local `DEVELOPER_DIR` may be stale; prefix builds with:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ...`
- **Broken history or thumbnails**: delete `~/Library/Application Support/Cap/History/index.json` and restart; the index is rebuilt from `images/`.
