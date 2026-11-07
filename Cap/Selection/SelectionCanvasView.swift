import AppKit

/// 选区覆盖层的绘制与鼠标处理。
///
/// 负责：压暗 + 挖孔 + 十字准星 + 尺寸标签 + 窗口高亮。
/// 交互状态由 `SelectionOverlayController` 驱动的 `SelectionModel` 决定，本视图只负责显示。
final class SelectionCanvasView: NSView {
    /// 当前鼠标位置（视图坐标，原点左下）。nil 表示尚未移动。
    private(set) var cursorPoint: CGPoint?

    /// 当前拖动矩形（视图坐标）。
    var selectionRect: CGRect? {
        didSet { needsDisplay = true }
    }

    /// 当前悬停窗口的矩形（视图坐标）。
    var highlightRect: CGRect? {
        didSet { needsDisplay = true }
    }

    /// 是否处于窗口模式（影响挖孔显示）。
    var isWindowMode = false {
        didSet { needsDisplay = true }
    }

    /// 未拖动时挖孔半径。
    private let holeRadius: CGFloat = 60

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let holeRect: CGRect? = selectionRect ?? highlightRect ?? holeRectAroundCursor()

        let maskPath = CGMutablePath()
        maskPath.addRect(bounds)
        if let holeRect {
            maskPath.addRect(holeRect)
        }

        context.saveGState()
        context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        context.addPath(maskPath)
        context.fillPath(using: .evenOdd)
        context.restoreGState()

        drawSelectionBorder(holeRect)
        drawCrosshair(in: context)
        drawSizeLabel(for: selectionRect)
    }

    private func holeRectAroundCursor() -> CGRect? {
        guard let point = cursorPoint else { return nil }
        return CGRect(
            x: point.x - holeRadius,
            y: point.y - holeRadius,
            width: holeRadius * 2,
            height: holeRadius * 2
        ).intersection(bounds)
    }

    private func drawSelectionBorder(_ rect: CGRect?) {
        guard let rect, rect.width > 0, rect.height > 0 else { return }
        let path = NSBezierPath(rect: rect)
        NSColor.white.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawCrosshair(in context: CGContext) {
        guard let point = cursorPoint else { return }
        context.saveGState()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: bounds.minX, y: point.y))
        context.addLine(to: CGPoint(x: bounds.maxX, y: point.y))
        context.move(to: CGPoint(x: point.x, y: bounds.minY))
        context.addLine(to: CGPoint(x: point.x, y: bounds.maxY))
        context.strokePath()
        context.restoreGState()
    }

    private func drawSizeLabel(for rect: CGRect?) {
        guard let rect, rect.width >= 1, rect.height >= 1 else { return }

        let text = "\(Int(rect.width.rounded())) × \(Int(rect.height.rounded()))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        let padding = CGSize(width: 6, height: 3)

        var origin = CGPoint(x: rect.minX, y: rect.minY - size.height - padding.height * 2 - 4)
        if origin.y < bounds.minY + 4 {
            origin.y = rect.maxY + 4
        }
        if origin.x + size.width + padding.width * 2 > bounds.maxX {
            origin.x = bounds.maxX - size.width - padding.width * 2 - 4
        }

        let background = CGRect(
            x: origin.x,
            y: origin.y,
            width: size.width + padding.width * 2,
            height: size.height + padding.height * 2
        )
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: background, xRadius: 4, yRadius: 4).fill()

        text.draw(
            at: CGPoint(x: background.minX + padding.width, y: background.minY + padding.height),
            withAttributes: attributes
        )
    }

    // MARK: - 鼠标

    override func mouseMoved(with event: NSEvent) {
        updateCursorPoint(convert(event.locationInWindow, from: nil))
    }

    override func mouseDown(with event: NSEvent) {
        updateCursorPoint(convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        updateCursorPoint(convert(event.locationInWindow, from: nil))
    }

    /// 更新光标位置并重绘。
    func updateCursorPoint(_ point: CGPoint) {
        cursorPoint = point
        needsDisplay = true
    }
}
