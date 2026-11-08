import AppKit

/// 编辑器画布：显示冻结底图与标注，并处理绘制工具的画布交互。
///
/// 坐标：视图是 flipped（左上原点），与图像像素坐标同向；
/// 缩放由 `CanvasGeometry` 负责（面板 point 尺寸 × Retina = 图像像素）。
final class EditorCanvasView: NSView {
    private let session: EditorSession
    /// 键盘事件回传给控制器。
    var onKeyDown: ((NSEvent) -> Bool)?
    /// 提交一条标注（拖拽/单击完成）。
    var onCommit: ((AnnotationKind) -> Void)?
    /// 提交裁剪。
    var onCrop: ((CGRect) -> Void)?
    /// 请求文字输入（像素坐标）。
    var onRequestText: ((CGPoint) -> Void)?

    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?
    private var penPoints: [CGPoint] = []

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
    override var isFlipped: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let rendered = AnnotationRenderer.render(session: session)
        context.interpolationQuality = .high
        // flipped 视图中需要先把图像翻正，再按视图尺寸缩放。
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(rendered, in: CGRect(origin: .zero, size: bounds.size))
        context.restoreGState()

        drawPreview(in: context)
    }

    private func drawPreview(in context: CGContext) {
        guard let draft = currentDraft() else { return }

        let imageSize = session.imageSize
        let viewSize = bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return }

        context.saveGState()
        // 视图是 flipped；缩放把图像像素映射到视图点。
        context.scaleBy(x: viewSize.width / imageSize.width, y: viewSize.height / imageSize.height)
        AnnotationRenderer.drawPreview(
            kind: draft,
            style: session.style,
            cropOrigin: session.cropRect?.origin ?? .zero,
            in: context,
            outputSize: session.outputSize,
            source: session.sourceImage
        )
        context.restoreGState()
    }

    private func currentDraft() -> AnnotationKind? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        let imageStart = CanvasGeometry.imagePoint(viewPoint: start, viewSize: bounds.size, imageSize: session.imageSize)
        let imageCurrent = CanvasGeometry.imagePoint(viewPoint: current, viewSize: bounds.size, imageSize: session.imageSize)
        let imagePen = penPoints.map {
            CanvasGeometry.imagePoint(viewPoint: $0, viewSize: bounds.size, imageSize: session.imageSize)
        }
        return AnnotationDraft.dragDraft(
            tool: session.tool,
            start: imageStart,
            current: imageCurrent,
            penPoints: imagePen
        )
    }

    func refresh() {
        needsDisplay = true
    }

    // MARK: - 鼠标

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragStart = point
        dragCurrent = point
        penPoints = [point]
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragStart != nil else { return }
        let point = convert(event.locationInWindow, from: nil)
        dragCurrent = point
        if session.tool == .pen {
            penPoints.append(point)
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart else { return }
        let point = convert(event.locationInWindow, from: nil)
        dragCurrent = point

        defer {
            dragStart = nil
            dragCurrent = nil
            penPoints = []
            needsDisplay = true
        }

        let imageStart = CanvasGeometry.imagePoint(viewPoint: start, viewSize: bounds.size, imageSize: session.imageSize)
        let imageCurrent = CanvasGeometry.imagePoint(viewPoint: point, viewSize: bounds.size, imageSize: session.imageSize)

        switch session.tool {
        case .number:
            onCommit?(.number(value: 0, center: imageCurrent)) // 数值由 session.addNumber 赋值
        case .text:
            onRequestText?(imageCurrent)
        case .crop:
            let rect = CanvasGeometry.imageRect(
                from: start, to: point, viewSize: bounds.size, imageSize: session.imageSize
            )
            if rect.width >= 1, rect.height >= 1 {
                onCrop?(rect)
            }
        default:
            let imagePen = penPoints.map {
                CanvasGeometry.imagePoint(viewPoint: $0, viewSize: bounds.size, imageSize: session.imageSize)
            }
            if let draft = AnnotationDraft.dragDraft(
                tool: session.tool,
                start: imageStart,
                current: imageCurrent,
                penPoints: imagePen
            ), AnnotationDraft.isMeaningful(draft) {
                onCommit?(draft)
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        super.keyDown(with: event)
    }
}
