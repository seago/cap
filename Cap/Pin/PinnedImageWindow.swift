import AppKit

/// 贴图钉屏窗口：无边框浮窗，可拖动、缩放；默认不进入截图。
final class PinnedImageWindow: NSPanel {
    private(set) var clickThrough = false

    init(frame: CGRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // 钉屏不应出现在截图里；测试时可用 CAP_EDITOR_CAPTURABLE=1 放进截图。
        let capturable = ProcessInfo.processInfo.environment["CAP_EDITOR_CAPTURABLE"] == "1"
        sharingType = capturable ? .readOnly : .none
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func setClickThrough(_ enabled: Bool) {
        clickThrough = enabled
        ignoresMouseEvents = enabled
    }
}
