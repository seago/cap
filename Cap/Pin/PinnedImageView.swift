import AppKit

/// 贴图窗口内容：绘制图片、滚轮缩放、拖动、右键菜单。
final class PinnedImageView: NSView {
    private var model: PinnedImageModel
    private let image: CGImage

    /// 需要移动窗口时回调（视图坐标 → 窗口 origin 由控制器算）。
    private var dragStartMouse: CGPoint?
    private var dragStartOrigin: CGPoint?

    var onZoom: ((CGFloat) -> Void)?
    var onClose: (() -> Void)?
    var onToggleClickThrough: (() -> Void)?
    var onCopy: (() -> Void)?

    init(image: CGImage, model: PinnedImageModel) {
        self.image = image
        self.model = model
        super.init(frame: CGRect(origin: .zero, size: model.displaySize))
        wantsLayer = true
        layer?.cornerRadius = 3
        layer?.masksToBounds = true
        setAccessibilityRole(.image)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.interpolationQuality = .high
        context.draw(image, in: bounds)
        NSColor.white.withAlphaComponent(0.18).setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()
    }

    func update(model: PinnedImageModel) {
        self.model = model
        frame.size = model.displaySize
        needsDisplay = true
    }

    // MARK: - 鼠标

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            // 双击：回到 100%
            if model.scale != 1 {
                onZoom?(1 / model.scale)
            }
            return
        }
        window?.makeKey()
        window?.makeFirstResponder(self)
        dragStartMouse = NSEvent.mouseLocation
        dragStartOrigin = window?.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStartMouse, let dragStartOrigin, let window else { return }
        let current = NSEvent.mouseLocation
        window.setFrameOrigin(CGPoint(
            x: dragStartOrigin.x + (current.x - dragStartMouse.x),
            y: dragStartOrigin.y + (current.y - dragStartMouse.y)
        ))
    }

    override func mouseUp(with event: NSEvent) {
        dragStartMouse = nil
        dragStartOrigin = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let copy = NSMenuItem(title: String(localized: "复制"), action: #selector(copyClicked), keyEquivalent: "")
        copy.target = self
        menu.addItem(copy)
        let through = NSMenuItem(title: String(localized: "点击穿透"), action: #selector(throughClicked), keyEquivalent: "")
        through.target = self
        menu.addItem(through)
        menu.addItem(.separator())
        let close = NSMenuItem(title: String(localized: "关闭"), action: #selector(closeClicked), keyEquivalent: "")
        close.target = self
        menu.addItem(close)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func scrollWheel(with event: NSEvent) {
        // 以鼠标位置为锚点缩放；不拦截触控板横向滚动。
        let delta = event.scrollingDeltaY
        guard abs(delta) > 0.01 else { return }
        // 触控板 delta 小、滚轮/像素 delta 大，分开调灵敏度。
        let factor = event.hasPreciseScrollingDeltas
            ? exp(delta * 0.005)
            : exp(delta * 0.08)
        onZoom?(factor)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Esc
            onClose?()
        default:
            super.keyDown(with: event)
        }
    }

    @objc private func copyClicked() { onCopy?() }
    @objc private func throughClicked() { onToggleClickThrough?() }
    @objc private func closeClicked() { onClose?() }
}
