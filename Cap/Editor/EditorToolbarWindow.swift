import AppKit

/// 工具条窗口：独立于面板，不抢焦点（nonactivating panel），不进入截图。
final class EditorToolbarWindow: NSPanel {
    init(contentSize: CGSize) {
        super.init(
            contentRect: CGRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let capturable = TestHooks.editorCapturable
        sharingType = capturable ? .readOnly : .none
        isMovable = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
