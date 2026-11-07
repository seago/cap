import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var hotKeyCenter: HotKeyCenter?
    private var onboardingController: OnboardingWindowController?

    private let screenCaptureService = ScreenCaptureService()
    private let clipboardWriter = ClipboardWriter()
    private let historyStore = HistoryStore()
    private var selectionOverlay: SelectionOverlayController?
    private var isCapturing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("Cap launched, version \(AppInfo.version, privacy: .public)")
        Log.app.notice("Screen recording permission: \(CGPreflightScreenCaptureAccess(), privacy: .public)")
        menuBarController = MenuBarController()

        let hotKeyCenter = HotKeyCenter()
        hotKeyCenter.onTrigger = { [weak self] in
            guard let self else { return }
            self.beginSelection()
        }
        if !hotKeyCenter.register() {
            Log.app.error("Failed to register ⌘⇧2")
        }
        self.hotKeyCenter = hotKeyCenter

        let onboardingController = OnboardingWindowController()
        onboardingController.showIfNeeded()
        self.onboardingController = onboardingController
    }

    func applicationWillTerminate(_ notification: Notification) {
        selectionOverlay?.dismiss()
        hotKeyCenter?.unregister()
        Log.app.info("Cap terminating")
    }

    /// ⌘⇧2：打开所有屏幕的选区覆盖层。
    private func beginSelection() {
        if let overlay = selectionOverlay, overlay.isPresented {
            overlay.cancel()
            return
        }
        guard CGPreflightScreenCaptureAccess() else {
            Log.selection.notice("Hotkey ignored: screen recording permission missing")
            onboardingController?.showIfNeeded()
            return
        }

        let overlay = SelectionOverlayController()
        overlay.onCancel = { [weak self] in
            self?.selectionOverlay = nil
            Log.selection.notice("Selection cancelled")
        }
        overlay.onSelect = { [weak self] target, options in
            self?.selectionOverlay = nil
            Task { await self?.capture(target: target, options: options) }
        }
        overlay.present()
        selectionOverlay = overlay
        Log.selection.notice("Selection overlay presented on \(overlay.windows.count, privacy: .public) screen(s)")
    }

    /// 按选区目标截取，成功则写剪贴板与历史。
    private func capture(target: SelectionTarget, options: CaptureOptions) async {
        guard !isCapturing else {
            Log.capture.notice("Capture already in progress; ignoring selection")
            return
        }
        isCapturing = true
        defer { isCapturing = false }

        // 覆盖层已关闭，等一帧让屏幕恢复原状。
        try? await Task.sleep(nanoseconds: 60_000_000)

        do {
            let mainHeight = ScreenCaptureService.mainScreenHeight()
            let image: CGImage
            let source: HistorySource
            switch target {
            case .region(let screenRect):
                let cgRect = WindowIndex.cgRect(fromScreenRect: screenRect, mainScreenHeight: mainHeight)
                image = try await screenCaptureService.capture(region: cgRect)
                source = .region(screenRect)
                Log.capture.notice("Captured region \(Int(cgRect.width), privacy: .public)x\(Int(cgRect.height), privacy: .public) pt")
            case .window(let windowID):
                image = try await screenCaptureService.capture(windowID: windowID, options: options)
                source = .window(windowID)
                Log.capture.notice("Captured window \(windowID, privacy: .public)")
            case .display(let displayID):
                image = try await screenCaptureService.capture(CaptureRequest(displayID: displayID))
                source = .display(displayID)
                Log.capture.notice("Captured display \(displayID, privacy: .public)")
            }

            try clipboardWriter.write(image)
            recordHistory(for: image, source: source)
            Log.capture.notice("Clipboard updated: \(image.width, privacy: .public)x\(image.height, privacy: .public) px")
        } catch {
            Log.capture.error("Capture failed: \(error.localizedDescription, privacy: .public)")
            presentCaptureError(error)
        }
    }

    /// 截图进剪贴板后写入历史；历史失败不应让已成功的截图变成失败。
    private func recordHistory(for image: CGImage, source: HistorySource) {
        do {
            let item = try historyStore.append(image, source: source)
            Log.history.notice("Inserted history item \(item.id.uuidString, privacy: .public) (\(image.width, privacy: .public)x\(image.height, privacy: .public) px)")
        } catch {
            Log.history.error("Failed to insert history item: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func presentCaptureError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "截图失败"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        NSApp.activate()
        alert.runModal()
    }
}
