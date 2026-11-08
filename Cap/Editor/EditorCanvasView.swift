import AppKit

/// 编辑器画布：显示冻结底图与标注预览。
/// 绘制交互（#18）与文字输入（#19）在此之上扩展。
final class EditorCanvasView: NSView {
    private let session: EditorSession
    /// 键盘事件回传给控制器。
    var onKeyDown: ((NSEvent) -> Bool)?

    init(session: EditorSession) {
        self.session = session
        super.init(frame: CGRect(origin: .zero, size: session.imageSize))
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let image = AnnotationRenderer.render(session: session)
        context.interpolationQuality = .high
        context.draw(image, in: bounds)
    }

    /// 重新渲染并刷新。
    func refresh() {
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        super.keyDown(with: event)
    }
}
