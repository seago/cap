import AppKit

/// 覆盖单个屏幕的无边框窗口。不进入截图、不进入切换器，可跨 Space 显示。
final class SelectionOverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        setFrame(screen.frame, display: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        // 关键：让 ScreenCaptureKit 排除自己，避免灰罩被截进图。
        // 测试时可用 CAP_OVERLAY_CAPTURABLE=1 让窗口进入 screencapture，便于自动化核对绘制。
        let capturable = ProcessInfo.processInfo.environment["CAP_OVERLAY_CAPTURABLE"] == "1"
        sharingType = capturable ? .readOnly : .none
        isMovable = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
