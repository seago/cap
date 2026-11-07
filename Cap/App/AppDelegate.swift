import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var hotKeyCenter: HotKeyCenter?
    private var onboardingController: OnboardingWindowController?

    private let screenCaptureService = ScreenCaptureService()
    private let clipboardWriter = ClipboardWriter()
    private var isCapturing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("Cap launched, version \(AppInfo.version, privacy: .public)")
        Log.app.notice("Screen recording permission: \(CGPreflightScreenCaptureAccess(), privacy: .public)")
        menuBarController = MenuBarController()

        let hotKeyCenter = HotKeyCenter()
        hotKeyCenter.onTrigger = { [weak self] in
            guard let self else { return }
            Task { await self.captureScreenToClipboard() }
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
        hotKeyCenter?.unregister()
        Log.app.info("Cap terminating")
    }

    private func captureScreenToClipboard() async {
        guard !isCapturing else {
            Log.capture.notice("Capture already in progress; ignoring hotkey")
            return
        }
        isCapturing = true
        defer { isCapturing = false }

        guard let displayID = ScreenCaptureService.displayUnderMouse() else {
            presentCaptureError(CaptureError.displayNotFound)
            return
        }

        do {
            let image = try await screenCaptureService.capture(CaptureRequest(displayID: displayID))
            try clipboardWriter.write(image)
            Log.capture.notice("Captured display \(displayID, privacy: .public), \(image.width)x\(image.height) px")
        } catch {
            Log.capture.error("Capture failed: \(error.localizedDescription, privacy: .public)")
            presentCaptureError(error)
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
