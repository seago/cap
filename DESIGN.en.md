# Cap · macOS Screenshot Tool — Design & Implementation Plan

> Status: 4th interview round complete; product decisions locked. Implementation status updated 2026-11-09.
> Date: 2026-11-08 · Working directory: `/Users/bruce/work/screenshot`
> Interview records: `.grill/answers-round1.json` … `.grill/answers-round4.json`
> [中文版](DESIGN.md)

---

## 0. One-page summary

- **Cap** is a menu-bar, hotkey-driven macOS screenshot tool. The core path is a single line: **⌘⇧2 → drag region / click window → annotate in place → Enter to copy, ⌘S to save**.
- Stack: **Swift 6 + SwiftUI (panels / settings) + AppKit (overlays / canvas) + ScreenCaptureKit single-frame capture + Carbon global hotkeys**, no App Sandbox, Xcode project.
- v1 scope: region / window / full-screen (cross-display), standard vector annotation, clipboard, manual save, 100-item auto history, menu-bar settings, launch at login.
- Not in v1: scrolling capture, OCR, pinned screenshots, upload, screen recording, delayed capture — planned for v1.1+, with architectural seams left in place.
- Status (2026-11-09): v1.1 has shipped scrolling capture, OCR, pinned screenshots, custom shortcuts and localization (zh-Hans / en / zh-Hant); upload/share remains. See §7 M4 and §10.
- Estimate: M0–M3 ≈ **5.5–8.5 focused workdays** (excluding app icon design and post-v1 features).
- Biggest technical trade-off: **raise the deployment target from macOS 14 to 15.2** to use `SCScreenshotManager.captureImage(in:)`, which supports cross-display capture. Staying on 14 would require a per-display capture-and-composite fallback.

---

## 1. Positioning & boundaries

### 1.1 User & scenarios

A tool for daily personal use, not a public product. Typical use: in any app, suddenly need an image with an arrow/text to send to a colleague or paste into a document; 5–20 times a day. The evaluation criterion is **frictionless**, not feature count.

### 1.2 Core path

1. In any context press **⌘⇧2**; all displays enter selection mode.
2. Hovering highlights a window; **drag = region, click = window, Space = toggle window/region, Enter = full screen under the mouse, Esc = cancel**.
3. On mouse-up capture happens; the original image is immediately pasteable (clipboard), the selection freezes into a floating editor, the rest of the screen stays live.
4. Annotate in place; **Enter = copy annotated and close; ⌘S = save annotated and close; Esc = close keeping the original**.
5. The image automatically enters history; open it from the menu bar when needed.

### 1.3 v1 scope

| Included | Excluded (v1.1+) |
|---|---|
| Region selection (any direction, cross-display, 1px accuracy) | Scrolling capture (shipped v1.1) |
| Window selection (hover highlight, click, shadow by default) | OCR / text recognition (shipped v1.1) |
| Full screen (display under mouse) | Pinned screenshots (shipped v1.1) |
| Multi-display (all displays covered, cross-display drag) | Upload / share (v1.1 pending) |
| Annotation: crop, rectangle, arrow, line, text, pen, highlight, mosaic/blur, number, undo/redo | Screen recording / GIF |
| Three colors (red/yellow/blue) + line-width slider + system font | Delayed capture |
| Clipboard (PNG + TIFF); annotated version overwrites | Full style panel, color picker, ellipse |
| Manual save as PNG / JPEG to a fixed folder, auto number on conflict | History "re-edit" |
| Automatic 100-item history: preview, copy, show in Finder, delete | Cloud sync, accounts, analytics |
| Menu-bar popover: recent screenshots, permission status, shortcuts, save settings, launch at login | App Store distribution / auto-update |
| First-run permission onboarding, revoked-permission warnings | Localization (v1 was Chinese-only; shipped in v1.1) |
| Launch at login; `.app` installed into `/Applications` | |

### 1.4 Definition of done

- **7 consecutive days, at least 5 real uses per day**; issues found go to the backlog and do not block v1 wrap-up.
- The critical-path checklist (§8.2) passes.
- Never requires Xcode to be running; must be installed in `/Applications` with launch at login enabled.

---

## 2. Locked decisions

| # | Decision | Conclusion |
|---|---|---|
| 1 | Product positioning | Personal tool; code written to productizable standards, no commercial metrics |
| 2 | Differentiator | Fast + in-place annotation (not scrolling capture / OCR / beautification / workflows) |
| 3 | Stack | Native Swift 6; minimum macOS 14 (raised to 15.2 — see §11) |
| 4 | Trigger | Menu-bar resident + custom full-screen selection overlay |
| 5 | Post-capture UX | Copy to clipboard immediately + float a lightweight editor |
| 6 | v1 scope | Standard v1; scrolling / OCR / pinning / upload after v1 |
| 7 | Selection interaction | Single hotkey + smart hover; drag region, click window, Space toggles |
| 8 | Editing container | Floating toolbar next to the selection (in-place editing) |
| 9 | Tool set | Standard group: minimal group + line, highlight, mosaic/blur, number |
| 10 | Save strategy | Copy + manual save; ⌘S writes directly with no dialog |
| 11 | History | In-app automatic history library (including unsaved captures) |
| 12 | Project form | Xcode project + local run; fixed bundle id |
| 13 | Multi-display | Cover all displays + cross-display drag |
| 14 | Editing timing | Selection frozen, rest of the screen live |
| 15 | Undo model | Vector operation stack; no post-selection editing in v1 |
| 16 | Shortcut | Default ⌘⇧2 (customizable since v1.1) |
| 17 | First authorization | Onboarding on first launch to grant screen recording |
| 18 | Development order | Vertical slices: full screen → selection → editing → history/wrap-up |
| 19 | Name | Cap (bundle id `dev.bruce.cap`) |
| 20 | Default annotation style | Native feel: red/yellow/blue + line-width slider + system font |
| 21 | History retention | Last 100 items, automatic cleanup |
| 22 | Settings form | Menu-bar dropdown panel; no standalone settings window |
| 23 | Delivery | Packaged `.app` in `/Applications` + launch at login |
| 24 | Definition of done | One week of daily use |

---

## 3. Interaction spec

### 3.1 Trigger

- Default global shortcuts: capture **⌘⇧2**, scrolling capture **⌘⇧7**, pin click-through toggle **⌥⌘P**; all recordable in the menu-bar popover.
- No third-party screenshot tool on this machine; macOS uses ⌘⇧3/4/5/6, hence ⌘⇧7 for scrolling capture (avoiding system and Touch Bar capture).
- Pressing the shortcut again while the overlay is open = cancel, back to idle.
- Missing permission: do not enter selection; the menu-bar icon shows a warning state and a permission prompt appears.

### 3.2 Selection overlay

One borderless transparent window per `NSScreen` (`sharingType = .none`), sharing a `SelectionModel`, using global screen coordinates. Each window draws only the part inside its own display.

| Action | Behavior |
|---|---|
| Hotkey | Enter selection overlay; the display under the mouse gets initial focus |
| Mouse move | Crosshair; in window mode highlight the window under the cursor |
| Press & drag > 3pt | Region selection with live size label |
| Click (movement < 3pt) | Capture the window under the cursor |
| Space | Toggle between region and window mode |
| Enter | Capture the whole display under the mouse |
| Esc | Cancel, back to idle |
| Mouse up | Capture immediately; on success close the overlay and enter editing |

Details:

- Background dimmed 30%; region/window brightened, creating a "hole punch" effect.
- Size label sits at the selection's bottom-right; flips above when there is no room.
- No magnifier (v1.1); fine adjustment is done with the editor's crop tool.
- The overlay must cover full-screen apps and all Spaces: `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`, window level above the system status bar; exact level verified in M1.
- Window hit-testing: build z-order from `CGWindowListCopyWindowInfo`, map to `SCShareableContent.windows`; exclude Cap's own windows, `windowLayer != 0`, tiny or invisible windows.

### 3.3 Capture & freeze

- On mouse-up: **capture first, close overlay, then show editor**; on capture failure keep the overlay and show a retry hint.
- The capture result is written to the clipboard immediately (original, PNG + TIFF).
- The frozen selection displays 1:1 at its original screen position; other displays stay live and the user can switch to another app; the editor stays on top.
- Editor window, toolbar and overlay all use `sharingType = .none` so they never appear in their own capture; this is verified in M1, with a "hide one frame then capture" fallback.

### 3.4 Editor

Layout: the toolbar floats 8pt below the selection; flips above when there is no room; otherwise sticks to the visible screen area. The toolbar is a separate window and does not steal focus.

**Tools (standard group, left to right)**

| Tool | Interaction | Notes |
|---|---|---|
| Close | Click / Esc | Discard annotations, keep the original |
| Crop | Drag a crop rect, release to apply | Undoable; one crop takes effect |
| Rectangle | Drag | Stroke only, no fill |
| Arrow | Drag, start = tail, end = head | Filled arrow |
| Line | Drag | Line width 2pt+ |
| Text | Click to position, type in place | System font; Enter commits, Esc cancels input |
| Pen | Freehand | Smoothed polyline |
| Highlight | Drag a rectangle | Translucent yellow, multiply blend |
| Mosaic | Drag a rectangle | Pixelated; applied to the underlying image at render time |
| Number | Click to place | Circular badge + white number, auto-incrementing; undo rolls the counter back |
| Undo / Redo | ⌘Z / ⇧⌘Z | Operation stack |
| Color | Red / Yellow / Blue | Red by default |
| Line width | 2–12 pt slider | 4 by default |
| Done | Enter / button | Copy annotated version and close |
| Save | ⌘S / button | Save annotated version, also copy, close |

**Shortcuts**: Enter done, ⌘C copy, ⌘S save, ⌘Z undo, ⇧⌘Z redo, Esc close (keep original), Delete removes the last annotation (when the canvas has focus).

**Rendering**: all annotations are vector objects stored in image pixel coordinates; export renders at the original image's pixel size for Retina sharpness. v1 has no selection/move/property editing.

### 3.5 Output

- **Clipboard**: original image on capture; annotated version after Enter / ⌘C / ⌘S. PNG + TIFF, compatible with most apps.
- **Save**: ⌘S writes directly, no dialog; default folder `~/Pictures/Screenshots/`, created if missing; default filename `Cap 2026-11-08 at 01.30.00.png`; conflicts get ` 2`, ` 3` suffixes.
- **Format**: PNG (default, lossless) / JPEG (optional, quality 0.85); switched in the popover.
- **Feedback**: a checkmark flashes on the menu-bar icon on success; on failure keep the editor and show an error.

### 3.6 Menu bar & history

- `NSStatusItem` with the SF Symbol `camera.viewfinder` (template rendering); no Dock icon (`LSUIElement`).
- Clicking opens an `NSPopover`:
  - Top: permission status (normal / not granted, with a "Grant" action when missing).
  - Recent screenshots: 2×4 grid, click to copy, right-click menu (copy / show in Finder / delete / recognize text / pin to screen).
  - "History": opens the history window (720×520) grid with preview, copy, show in Finder, delete.
  - Settings area: shortcut recording, save folder, format, launch at login, localization note (follows the system language), clear history, quit.
- Apart from first-run onboarding, the history window is the only extra window; settings stay inside the popover (round-4 decision).
- Capture/copy completion uses lightweight feedback only; no Notification Center.

### 3.7 First launch & permissions

1. Show onboarding on first launch (temporarily switch activation policy to `.regular`, then back to `.accessory`).
2. Copy states that Cap needs screen recording permission; images are processed only on this Mac, never uploaded.
   - Scrolling capture additionally needs Accessibility permission (to scroll the target app); requested on demand, and its absence does not block normal capture.
3. Primary button "Grant Permission" → `CGRequestScreenCaptureAccess()`; users who already denied are not asked again, so open the System Settings deep link instead.
4. "Check Again" button → `CGPreflightScreenCaptureAccess()`; if the system requires a process restart, show "Restart Cap".
5. Until permission is granted the menu-bar icon stays in a warning state; shortcut presses show onboarding instead of entering selection.

### 3.8 Errors & empty states

| Situation | Handling |
|---|---|
| Permission denied / revoked | Onboarding + menu-bar warning; never fail silently |
| Capture API error | Keep the overlay, show a toast "Capture failed; retry or press Esc" |
| Save failure (folder not writable) | Keep the editor, prompt to choose a new folder |
| Shortcut registration failure | Highlight in settings and ask for another combination |
| Corrupted history index | Rescan the image folder and rebuild; drop unparseable entries |
| Hotkey conflict (other app) | Carbon does not report it and cannot detect it reliably; warn about system-reserved combos while recording; otherwise let the user adjust |

---

## 4. Technical baseline

### 4.1 Project & platform

| Item | Decision |
|---|---|
| Project | Xcode project (`Cap.xcodeproj`), no SwiftPM packaging |
| Language | Swift 6 language mode; AppKit + SwiftUI mixed |
| Minimum OS | **macOS 15.2** (see 4.2) |
| Target machine | macOS 27.2 / arm64; this machine is the only target |
| App form | `LSUIElement = YES`, menu-bar app, no Dock |
| Bundle ID | `dev.bruce.cap` (TCC permissions are bound to it; never changes) |
| Display name | Cap |
| Version | 0.1.0 |
| App Sandbox | **Off** (personal tool, direct image folder access, no security-scoped bookmarks) |
| Signing | Local self-signed certificate (recommended); ad-hoc causes TCC re-prompts after rebuilds |
| Notarization / App Store | Not in v1 |
| Third-party dependencies | None; hotkeys are a thin Carbon wrapper |
| Test framework | Swift Testing (`import Testing`) |
| Logging | `OSLog`, categories `capture` / `selection` / `editor` / `history` |
| Localization | String Catalog (`.xcstrings`), development language `zh-Hans`, languages `en` / `zh-Hans` / `zh-Hant` |

### 4.2 SDK verification (macOS 27.2 SDK, statically verified)

SDK root: `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk`

| Fact | Evidence |
|---|---|
| `SCScreenshotManager` available since **macOS 14.0**, still the right entry point for single-frame capture | `ScreenCaptureKit.framework/Headers/SCScreenshotManager.h:135` |
| `captureImage(contentFilter:configuration:)` exists, returns `CGImage`, async bridging works | same file `:153` |
| `captureImage(in:)` available since **macOS 15.2**; takes a **cross-display, display-agnostic screen-space rect** and returns the region in one call | same file `:161` |
| macOS 26 adds `SCScreenshotConfiguration` / `SCScreenshotOutput` / `captureScreenshot(rect:configuration:)` with direct PNG/JPEG/HEIC, HDR and shadow switches; not needed for v1 | same file `:46`, `:118`, `:179` |
| `SCStreamConfiguration.ignoreShadowsSingleWindow` and `ignoreShadowsDisplay` available since macOS 14; shadows **included** by default | `SCStream.h:335`, `:340` |
| `showsCursor` available since macOS 12.3; cursor included by default, disabled while capturing | `SCStream.h:274` |
| `CGPreflightScreenCaptureAccess()` available since 10.15, no prompt, query only | `CoreGraphics.framework/Headers/CGWindow.h:300` |
| `CGRequestScreenCaptureAccess()` available since 10.15; **already-denied processes are not asked again**, must go to System Settings | same file `:308`, comments `:295–305` |
| `CGWindowListCreateImage` is marked `SCREEN_CAPTURE_OBSOLETE(10.5,14.0,15.0)` — **not used** | same file `:271–274` |
| Carbon `RegisterEventHotKey` still present (HIToolbox); registering the same combination in multiple processes is not an error | `Carbon.framework/.../HIToolbox.framework/.../Headers/CarbonEvents.h`, `CarbonEventsCore.h:143–152` |
| `SMAppService.mainApp` available since macOS 13, used for launch at login | `ServiceManagement.framework/Headers/SMAppService.h:91` |
| SwiftUI `MenuBarExtra` available since macOS 13; this project uses `NSStatusItem` instead (see 4.8) | `SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface:2378` |
| With a macOS 14 deployment target, `SCScreenshotManager` single-frame/window/display APIs compile in **Swift 6 mode** | probe: `swiftc -typecheck -swift-version 6 -target arm64-apple-macos14.0 -sdk "$(xcrun --show-sdk-path)" /tmp/cap_probe.swift` → passes |

**Resulting recommendation**: raise the minimum to **15.2** so `captureImage(in:)` returns a cross-display rect in one call, avoiding per-display capture plus coordinate/DPI compositing. Staying on 14 would need an extra fallback (≈40–60 lines + tests), while the target machine is 27.2 anyway.

### 4.3 Capture strategy

| Scenario | API |
|---|---|
| Full screen | `SCContentFilter(display:excludingWindows:)` + `SCStreamConfiguration` (width/height from display pixel size) → `SCScreenshotManager.captureImage` |
| Window | `SCContentFilter(desktopIndependentWindow:)` + configuration; `ignoreShadowsSingleWindow = false` (shadow kept by default); Option-click sets `true` |
| Region | **Preferred** `SCScreenshotManager.captureImage(in: globalRect)` (15.2+); 14 fallback is per-display capture + composite |
| Cursor | `showsCursor = false` |
| Excluding own windows | Overlay / editor / toolbar all `NSWindow.sharingType = .none`; verified in M1 whether SCK honors it. If not, hide for one frame before capturing |
| Not used | `CGWindowListCreateImage` (obsolete), `SCStream` (not needed for single frames) |

### 4.4 Coordinates & Retina

- All geometry conversion centralized in `Geometry`: AppKit bottom-left origin ↔ CG top-left origin ↔ global screen space ↔ image pixel coordinates.
- Selection and editor panels use **points**; saving and annotation use **pixels**.
- Image pixel size = selection width/height × the backingScaleFactor of the corresponding display; with mixed-DPI cross-display selections, the output image's pixel coordinate system wins, and the scale factor is fixed after M1 verification.
- Clipboard writes keep pixel dimensions (`NSBitmapImageRep.size` set to point size) so pasted images are not unexpectedly enlarged.

### 4.5 Global shortcuts

- A ~80-line `HotKeyCenter` wrapping `RegisterEventHotKey` + `InstallEventHandler`, no third-party library.
- Defaults (implemented 2026-11-09): capture ⌘⇧2, scrolling capture ⌘⇧7, pin click-through toggle ⌥⌘P.
- Three recorder controls in settings (`ShortcutRecorderButton`): click to record, ⌫ restores default, Esc cancels; at least one of ⌘/⌥/⌃ is required.
- While recording, **all global hotkeys are temporarily unregistered**; otherwise pressing an existing combination triggers its action instead of being recorded. They are re-registered from current settings afterwards.
- Changes are applied immediately and persisted; conflicts or registration failures keep the previous setting and show a message. Carbon does not report cross-process conflicts (the header states that registering the same combination in multiple processes is not an error), so conflicts are only discovered in practice.
- Global hotkeys do not need Accessibility permission, which is why Carbon beats `NSEvent.addGlobalMonitorForEvents` (but scrolling capture's auto-scroll does need Accessibility).

### 4.6 Permissions

- On launch: `CGPreflightScreenCaptureAccess()`; no prompt.
- Onboarding button calls `CGRequestScreenCaptureAccess()`; already-denied users are not asked again, open:
  `x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`
- Listen for `NSApplication.didBecomeActiveNotification` and re-check permissions when returning to the foreground.
- Accessibility (scrolling capture): if auto-scroll fails and `AXIsProcessTrusted() == false`, call `AXIsProcessTrustedWithOptions(prompt)`; on macOS 27 granting Cap in System Settings requires admin password confirmation.
- If SCK still reports a permission error after granting, offer "Restart Cap" (`NSWorkspace.open` self + `NSApp.terminate`).
- M0 measured whether a restart is actually required; behavior differs across macOS versions, so docs do not assume.

### 4.7 Signing & TCC

- TCC records authorization by code-signing identity; an ad-hoc designated requirement may change on every rebuild, forcing re-authorization after edits.
- Recommended: create a self-signed **Code Signing** certificate (e.g. `Cap Local Signing`) in Keychain, sign both Debug and Release with it; keep the `.app` at the fixed path `/Applications/Cap.app`.
- If self-signing is not possible: ad-hoc + fixed bundle id + fixed path, accept occasional re-authorization; record actual behavior in M0.
- Hardened Runtime off (personal use); enable later if notarizing.
- `SMAppService.mainApp.register()` for launch at login; requires the app in `/Applications` and a stable signature.

### 4.8 Explicitly rejected

| Option | Reason |
|---|---|
| `CGWindowListCreateImage` | Deprecated in macOS 14, obsolete in 15 |
| `SCStream` for single frames | More complex than `SCScreenshotManager`, costly callback/lifecycle handling |
| SwiftUI `MenuBarExtra` | Less control over popover behavior, permission windows and global hotkeys than `NSStatusItem` |
| App Sandbox | Personal tool; direct folder access is simpler; re-evaluate for distribution |
| Electron / Tauri | Capture and permission chains are more convoluted; no cross-platform need |
| SwiftPM + script packaging | Info.plist / signing / login items would all have to be assembled manually |
| Third-party hotkey libraries | Single simple need; an 80-line Carbon wrapper avoids a dependency |

---

## 5. Architecture

### 5.1 Module diagram

```
CapApp (AppDelegate, LSUIElement)
├─ HotKeyCenter            Carbon global hotkeys
├─ MenuBarController       NSStatusItem + NSPopover
│   ├─ MenuBarView         SwiftUI: recent screenshots / settings / permissions
│   └─ HistoryWindow       History grid (NSPanel + SwiftUI)
├─ CaptureFlowController   State machine & flow orchestration
│   ├─ PermissionService   preflight / request / deep link
│   ├─ ScreenCaptureService ScreenCaptureKit wrapper
│   ├─ WindowIndex         SCShareableContent + CGWindowList hit-testing
│   ├─ SelectionOverlayController  one overlay window per display
│   ├─ EditorController    NSPanel + NSView canvas + SwiftUI toolbar
│   └─ OutputService       clipboard / file writes
├─ HistoryStore            Application Support + JSON index
└─ SettingsStore           UserDefaults
```

### 5.2 Directory structure

```
screenshot/
├─ Cap.xcodeproj
├─ Cap/
│  ├─ App/                 CapApp.swift, AppDelegate.swift, AppEnvironment.swift
│  ├─ MenuBar/             MenuBarController.swift, MenuBarView.swift, HistoryWindow.swift
│  ├─ Capture/             ScreenCaptureService.swift, CaptureRequest.swift,
│  │                       WindowIndex.swift, ImageCompositor.swift
│  ├─ Selection/           SelectionOverlayController.swift, SelectionOverlayWindow.swift,
│  │                       SelectionModel.swift, SelectionCanvasView.swift
│  ├─ Editor/              EditorController.swift, EditorCanvasView.swift,
│  │                       EditorToolbar.swift, Annotation.swift,
│  │                       AnnotationRenderer.swift, TextEditingController.swift
│  ├─ Output/              ClipboardWriter.swift, FileExporter.swift, ImageEncoder.swift
│  ├─ History/             HistoryStore.swift, HistoryItem.swift, Thumbnailer.swift
│  ├─ Permissions/         ScreenRecordingPermission.swift, OnboardingWindowController.swift
│  ├─ Settings/            SettingsStore.swift, ShortcutRecorderView.swift
│  ├─ HotKey/              HotKeyCenter.swift
│  ├─ Support/             Geometry.swift, Logging.swift, FileNaming.swift
│  └─ Resources/           Assets.xcassets, Info.plist, Localizable.xcstrings
├─ CapTests/               GeometryTests, SelectionStateTests, AnnotationUndoTests,
│                          HistoryRetentionTests, FileNamingTests, LocalizationTests
└─ DESIGN.md
```

### 5.3 Core types (draft)

```swift
enum CaptureSource {
    case region(CGRect)               // global screen coordinates (points)
    case window(CGWindowID)
    case display(CGDirectDisplayID)
}

struct CaptureResult {
    let image: CGImage               // pixel coordinates
    let scale: CGFloat               // pixels/point
    let capturedAt: Date
}

protocol ScreenCapturing {
    func capture(_ source: CaptureSource, excluding: [CGWindowID]) async throws -> CaptureResult
}

enum SelectionState {
    case idle
    case overlay(SelectionSession)
    case editing(EditorSession)
    case capturing
}

struct SelectionSession {
    var mode: Mode                   // .region / .window
    var dragRect: CGRect
    var hoveredWindow: WindowHit?
}

struct EditorSession {
    let capture: CaptureResult
    var cropRect: CGRect?
    var annotations: [Annotation]
    var undo: [EditorCommand]
    var redo: [EditorCommand]
    var tool: Tool
    var style: AnnotationStyle
}

enum AnnotationKind {
    case rectangle, arrow, line, text(String), pen([CGPoint]),
         highlight, mosaic, number(Int)
}
```

### 5.4 State machine

```
idle
  --hotkey--> permissionGate
permissionGate
  --granted--> indexing (SCShareableContent snapshot)
  --denied--> onboarding
indexing
  --ready--> overlay
overlay
  --drag--> dragging --mouseUp--> capturing
  --clickWindow--> capturing
  --space--> toggle region/window
  --enter--> capturing(displayUnderMouse)
  --esc--> idle
capturing
  --success--> editing
  --failure--> overlay (kept, retry hint)
editing
  --enter/cmdC--> copyAnnotated --> idle
  --cmdS--> saveAnnotated --> idle
  --esc--> keepRaw --> idle
```

### 5.5 Data flow

```
hotkey
  → PermissionService.check()
  → SCShareableContent.excludingDesktopWindows(...) (windows + displays)
  → SelectionOverlayController shows overlays
  → user drags/clicks
  → ScreenCaptureService.capture(source)
  → ClipboardWriter.write(raw) + HistoryStore.insert(raw)
  → EditorController.present(frozen image)
  → user annotates
  → AnnotationRenderer.render(session) -> CGImage
  → ClipboardWriter.write(annotated) / FileExporter.save(annotated)
  → HistoryStore.replace(id, annotated)
```

### 5.6 Concurrency & errors

- UI, controllers and window operations are all `@MainActor`.
- SCK calls are `async`; results return to the main thread before updating the UI.
- A probe verified that `SCScreenshotManager` async calls compile in Swift 6 mode; if Sendable warnings appear, use `@preconcurrency import ScreenCaptureKit` rather than weakening global concurrency checks.
- Custom `CapError` (permission, capture, encoding, write, hotkey registration), surfaced uniformly from the menu bar; logs keep the last 100 entries.

---

## 6. Storage & data

### 6.1 History

Location: `~/Library/Application Support/Cap/History/`

```
History/
├─ index.json          // [HistoryItem], newest first
├─ images/{uuid}.png   // original or annotated
└─ thumbs/{uuid}.jpg   // 320px thumbnail
```

`HistoryItem`: `id`, `createdAt`, `source`, `pixelWidth`, `pixelHeight`, `fileName`, `isAnnotated`, `ocrText` (v1.1).

- A raw record is inserted as soon as capture succeeds; when the editor finishes (Enter / ⌘S) the record is replaced by the annotated version with `isAnnotated = true`; Esc keeps the original.
- Beyond 100 records, the oldest is deleted (files included).
- Atomic index writes (temp file + rename); validated on launch, rebuilt by scanning `images/` if corrupted.
- No cloud sync, no analytics.

### 6.2 Settings (UserDefaults)

| Key | Default |
|---|---|
| `hotKey.<action>.keyCode` / `.modifiers` | capture ⌘⇧2, scrolling ⌘⇧7, pin click-through ⌥⌘P |
| `saveFolderPath` | `~/Pictures/Screenshots` |
| `imageFormat` | `png` (optionally `jpeg`) |
| `jpegQuality` | 0.85 |
| `launchAtLoginDefaultApplied` | set to true after the first-launch login item registration (actual state from `SMAppService`) |
| `historyLimit` | 100 (not exposed in v1) |
| `cap.accessibilityPrompted` | set to true after the first scrolling-capture Accessibility prompt |

### 6.3 Saving

- Filename: `Cap yyyy-MM-dd 'at' HH.mm.ss.<ext>`; conflicts append ` 2`, ` 3`.
- Folder not writable: prompt and change folder in settings; annotations are never lost.
- Write via temp file + rename to avoid half-written images.

### 6.4 Privacy

- No network requests, no third-party SDKs.
- Images only flow between local memory, clipboard, history folder and the user-chosen save folder.
- History can be cleared with one action; the menu bar shows disk usage.

---

## 7. Milestones

> Estimates are "focused workdays", not calendar days; vertical slices, each milestone independently verifiable.

### M0 · Skeleton & full-screen capture (0.5–1 day)

- Xcode project, `LSUIElement`, menu-bar icon, AppDelegate.
- `HotKeyCenter` (⌘⇧2) + recorder entry (hardcoded is fine initially).
- Permission onboarding + preflight / request / deep link / re-check.
- `SCScreenshotManager` full-screen capture of the display under the mouse → clipboard.
- History folder and a minimal `HistoryStore` (store one item).

**Acceptance**: clean install → onboarding grant → quit Xcode → reboot → ⌘⇧2 still copies a screenshot; permissions survive rebuilds (otherwise switch to a self-signed certificate).

### M1 · Selection overlay (1.5–2.5 days)

- Multi-display overlays, dimming, crosshair, window highlight, size labels.
- Drag / click / Space / Enter / Esc; 3pt threshold.
- Region capture (15.2 cross-display API), window capture (with shadow), full screen.
- Verify own windows are excluded; hide one frame if needed.
- Capture immediately goes to clipboard + history.
- Error paths for revoked permissions and failed captures.

**Acceptance**: in a dual-display setup, 20 consecutive region/window captures without Cap's own UI in the output; correct cross-display sizes; stable Esc / Space / Enter behavior.

### M2 · Editor (2–3 days)

- Frozen panel, in-place toolbar, edge flipping.
- Standard 9 tools + undo/redo + three colors / line widths.
- Text input (including Chinese IME), Retina export.
- Enter copies the annotated version, ⌘S saves, Esc keeps the original.
- History entry replaced by the annotated version.

**Acceptance**: draw with every standard tool; 10-step undo returns to the original; Chinese input works; exported pixels match the original; name conflicts do not overwrite.

### M3 · Product surface (1.5–2 days)

- Popover: recent screenshots, settings, permission status, quit.
- History window: grid, preview, copy, Finder, delete, clear.
- Save folder selection, format switching, launch at login.
- Package `.app` into `/Applications`, icon, first-launch polish.
- Error messages, logging, performance checks.

**Acceptance**: installed in `/Applications`, launch at login, used daily for a week; critical-path checklist passes.

**Total**: ≈5.5–8.5 focused workdays; the biggest uncertainty is M1 (overlay/capture coexistence, mixed DPI).

### M4 · v1.1 (implemented, 2026-11-09)

| Capability | Status | Key points |
|---|---|---|
| Scrolling capture | ✅ Accepted | ⌘⇧7 select region → AXRaise target window + HID scroll wheel → per-frame stitching; needs Accessibility; sticky headers/dynamic content may stop early (ambiguity guard, never emits a misaligned image) |
| OCR | ✅ Accepted | On-device Vision Chinese/English recognition; right-click "Recognize Text" copies and stores `ocrText` |
| Pinned screenshots | ✅ Accepted | Editor ⌘T / history right-click "Pin to Screen"; drag/zoom/click-through/close; ⌥⌘P toggles click-through globally; `sharingType=.none` keeps them out of captures |
| Custom shortcuts | ✅ Accepted | Three recordable actions; conflict warnings; hotkeys temporarily unregistered while recording |
| Localization | ✅ Accepted | zh-Hans / en / zh-Hant String Catalog, follows the system language; 124 keys |
| Upload / share | ⏳ Pending | See §10; plan: user-configured HTTP endpoint + `UploadService` protocol |

**Acceptance**: 177 unit tests + live smoke tests (scrolling capture, OCR, pinning, shortcut recording, English UI); commits in git (`7274185`, `a2cf38c`, `27035f9`, `0d7a8e7`, `30af388`).

---

## 8. Test plan

### 8.1 Unit tests

| Test | Content |
|---|---|
| `GeometryTests` | AppKit ↔ CG coordinates, cross-display rects, Retina scale, display origins |
| `SelectionStateTests` | 3pt threshold, Space toggle, Enter target display, Esc reset |
| `AnnotationUndoTests` | Add / undo / redo, number rollback, undoable crop |
| `FileNamingTests` | Time format, conflict suffixes, illegal characters |
| `HistoryRetentionTests` | 100-item pruning, index rebuild on corruption, annotated replacement |
| `ImageEncoderTests` | PNG / JPEG dimensions and DPI metadata |
| `LocalizationTests` | All three languages shipped, key translations, placeholder parity |

### 8.2 Manual test matrix

| Dimension | Cases |
|---|---|
| Displays | Built-in only, 1 external, 2 external, mixed Retina/1x, scaled resolutions |
| Selection | Four-direction drag, 1px, full display, cross-display, click window, full-screen app, different Spaces, Stage Manager |
| Permissions | First denial, grant in System Settings, revoke while running, restart app, rebuild app |
| Shortcuts | ⌘⇧2, occupied by another app, sleep/wake, user remapping |
| Editor | Every tool, 10-step undo, Chinese input, near screen edges, cross-display selection |
| Windows | With/without shadow, partially off-screen, minimized, full-screen |
| Output | Paste into Notes / Mail / Keynote / Finder, Retina size, PNG/JPEG, duplicate names |
| History | 101st item, delete, clear, corrupted index, survives restart |
| Stress | 50 consecutive captures, memory not growing, hotkey responsiveness |
| Localization | System language en / zh-Hant, reboot to apply, no missing keys |

**Critical-path checklist**: permission → hotkey → region → window → full screen → copy → annotate → copy → save → retrieve from history → still works after restart.

### 8.3 Performance targets

- Hotkey → overlay visible: **< 150ms**
- Mouse-up → pasteable clipboard: **< 400ms** (6K region)
- Idle memory: **< 200MB**; no sustained growth after 50 captures
- 100-item history: **< 2GB**; thumbnails < 20KB each

---

## 9. Risks & unknowns

| # | Risk | Impact | Mitigation | Verified |
|---|---|---|---|---|
| 1 | TCC re-promps after rebuilds | Daily interruption | Self-signed certificate + fixed path; measure in M0 | M0 |
| 2 | Overlay captured by SCK | Every image has a gray veil | `sharingType = .none`; hide one frame if ineffective | M1 |
| 3 | Mixed-DPI cross-display size mismatch | Blurry / misaligned images | Prefer 15.2 cross-display API; per-display fallback; fix after M1 | M1 |
| 4 | Non-activating panel cannot type text | Text tool unusable | Temporarily `makeKey` when the text tool is active; or use an activatable panel | M2 |
| 5 | Full-screen apps / multiple Spaces not covered | Cannot capture | `.canJoinAllSpaces` + `.fullScreenAuxiliary`; verify level | M1 |
| 6 | Carbon hotkey conflicts with other apps | No response or double trigger | Recorder + warnings for reserved combos; allow remapping | M0 |
| 7 | Restart required after granting | Broken first-run experience | Onboarding offers "Restart Cap" | M0 |
| 8 | Large images × 100 history items | Disk growth | 100-item cap, thumbnails, clear action | M3 |
| 9 | Swift 6 concurrency friction with AppKit | Compile/runtime warnings | SCK probe passed; MainActor boundaries; `@preconcurrency` | M0 |
| 10 | Window hit-test order inaccurate | Wrong window captured | CGWindowList z-order; exclude own/non-zero layers; measure | M1 |
| 11 | Localization keys drift from code | Missing translations | `LocalizationTests` + `-exportLocalizations` extraction step | M5 |

---

## 10. After v1

Order: **scrolling capture → OCR → pinned screenshots → upload / share**.
Status (2026-11-09): the first three are implemented and accepted, plus custom shortcuts and localization; upload is pending.

- **Scrolling capture** (implemented): select a region → AXRaise the target window to the front → per-frame capture + HID scroll wheel events → `ScrollStitcher` feature-matching stitch. Verified on a long Chrome page (1100×2625) with no misalignment; `CGEvent.postToPid` does not work for Chrome and the first scroll frame is occasionally swallowed — both handled (duplicate-frame retry). Limitation: sticky headers/dynamic content may stop it early (stop rather than emit a misaligned image).
- **OCR** (implemented): Vision `VNRecognizeTextRequest`, on-device and offline, mixed Chinese/English; result copied and stored in `HistoryItem.ocrText`.
- **Pinned screenshots** (implemented): borderless `NSPanel` showing an image; drag, scroll-wheel anchored zoom (0.1–8x), double-click reset, Esc close, right-click copy/click-through; excluded from captures by default.
- **Upload / share**: needs a target service decision (self-hosted / image host / clipboard sharing); leave an `UploadService` protocol and keep network logic out of the capture flow.
- **Architectural seams**: `OutputService` is already a replaceable outlet; `HistoryItem` has an `ocrText` field; the editor renderer is decoupled from capture, so pinning reuses rendered output.

---

## 11. The five confirmed defaults

Status: confirmed (2026-11-08), all implemented:

1. **Minimum OS**: raised from 14 to **macOS 15.2** to use the cross-display single-capture API; staying on 14 would add a per-display compositing fallback.
2. **Window captures include shadows by default**: click captures with shadow/corners; Option-click captures without.
3. **Original vs annotated**: capture copies the original and enters history; Enter / ⌘S overwrite clipboard and history with the annotated version; Esc keeps the original. History keeps only the final version.
4. **Save defaults**: `~/Pictures/Screenshots/`, `Cap 2026-11-08 at 01.30.00.png`, PNG default, JPEG optional.
5. **Post-v1 order**: scrolling → OCR → pinning → upload. Status (2026-11-09): scrolling / OCR / pinning shipped; upload pending.

---

## Appendix A · Interview answers

| Round | File |
|---|---|
| Round 1 | `.grill/answers-round1.json` |
| Round 2 | `.grill/answers-round2.json` |
| Round 3 | `.grill/answers-round3.json` |
| Round 4 | `.grill/answers-round4.json` |

Page sources: `.grill/round1.html` … `.grill/round4.html`; local server `server.py`.

## Appendix B · SDK verification commands

```bash
SDK=$(xcrun --show-sdk-path --sdk macosx)
grep -n "SCScreenshotManager\|captureImageInRect" \
  "$SDK/System/Library/Frameworks/ScreenCaptureKit.framework/Headers/SCScreenshotManager.h"
grep -n "ignoreShadowsSingleWindow" \
  "$SDK/System/Library/Frameworks/ScreenCaptureKit.framework/Headers/SCStream.h"
grep -n "PreflightScreenCaptureAccess\|RequestScreenCaptureAccess\|SCREEN_CAPTURE_OBSOLETE" \
  "$SDK/System/Library/Frameworks/CoreGraphics.framework/Headers/CGWindow.h"
swiftc -typecheck -swift-version 6 -target arm64-apple-macos14.0 -sdk "$SDK" /tmp/cap_probe.swift
```

> Note: the above are static SDK checks plus compile probes. TCC restart behavior, whether the overlay is captured, and mixed-DPI measurements will be replaced by runtime results during M0 / M1.
