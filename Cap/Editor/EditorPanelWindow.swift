import AppKit

/// 冻结面板：覆盖在截取区域上，显示定格底图与标注。
final class EditorPanelWindow: NSWindow {
    init(frame: CGRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = true
        backgroundColor = .black
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // 截图时排除自己；测试时可用 CAP_EDITOR_CAPTURABLE=1 让窗口进入 screencapture。
        let capturable = TestHooks.editorCapturable
        sharingType = capturable ? .readOnly : .none
        isMovable = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
