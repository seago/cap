import AppKit

/// 历史窗口网格中的单张截图卡片（#23）：缩略图 + 时间 + 像素尺寸。
///
/// 交互：
/// - 单击：复制到剪贴板；
/// - 双击 / 右键「预览」：打开大图预览；
/// - 右键菜单：预览 / 复制 / 在 Finder 中显示 / 删除。
@MainActor
final class HistoryGridItemView: NSView {
    static let size = NSSize(width: 160, height: 148)

    var onPreview: (() -> Void)?
    var onCopy: (() -> Void)?
    var onRevealInFinder: (() -> Void)?
    var onDelete: (() -> Void)?

    private let thumbnailView = NSImageView()
    private let dateLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let contextMenu = NSMenu()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    init(item: HistoryItem, thumbnail: NSImage?) {
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        translatesAutoresizingMaskIntoConstraints = true
        buildSubviews()
        buildContextMenu()
        configure(with: item, thumbnail: thumbnail)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 更新展示内容。
    func configure(with item: HistoryItem, thumbnail: NSImage?) {
        thumbnailView.image = thumbnail
        dateLabel.stringValue = Self.dateFormatter.string(from: item.createdAt)

        var detail = "\(item.pixelWidth)×\(item.pixelHeight)"
        if item.isAnnotated {
            detail += " · 已标注"
        }
        detailLabel.stringValue = detail

        toolTip = "\(dateLabel.stringValue)\n\(item.pixelWidth)×\(item.pixelHeight) px\n单击复制，右键查看更多操作"
        setAccessibilityLabel("\(dateLabel.stringValue)，\(detail)")
        setAccessibilityRole(.button)
    }

    // MARK: - 交互

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onPreview?()
            return
        }
        guard event.clickCount == 1 else {
            super.mouseDown(with: event)
            return
        }
        onCopy?()
    }

    // MARK: - 视图

    private func buildSubviews() {
        wantsLayer = true

        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.imageAlignment = .alignCenter
        thumbnailView.wantsLayer = true
        thumbnailView.layer?.cornerRadius = 4
        thumbnailView.layer?.masksToBounds = true
        thumbnailView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = .systemFont(ofSize: 11, weight: .medium)
        dateLabel.textColor = .labelColor
        dateLabel.lineBreakMode = .byTruncatingTail

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .systemFont(ofSize: 10)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail

        addSubview(thumbnailView)
        addSubview(dateLabel)
        addSubview(detailLabel)

        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            thumbnailView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            thumbnailView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            thumbnailView.heightAnchor.constraint(equalToConstant: 96),

            dateLabel.topAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: 7),
            dateLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            dateLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            detailLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 2),
            detailLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        ])
    }

    private func buildContextMenu() {
        addMenuItem(title: "预览", action: #selector(previewClicked))
        addMenuItem(title: "复制", action: #selector(copyClicked))
        addMenuItem(title: "在 Finder 中显示", action: #selector(revealClicked))
        addMenuItem(title: "删除", action: #selector(deleteClicked))
        menu = contextMenu
    }

    private func addMenuItem(title: String, action: Selector) {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        contextMenu.addItem(menuItem)
    }

    @objc private func previewClicked() {
        onPreview?()
    }

    @objc private func copyClicked() {
        onCopy?()
    }

    @objc private func revealClicked() {
        onRevealInFinder?()
    }

    @objc private func deleteClicked() {
        onDelete?()
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let cardRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: cardRect, xRadius: 8, yRadius: 8)
        NSColor.controlBackgroundColor.setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: // Return / Enter
            onPreview?()
        case 51, 117: // Delete / Forward Delete
            onDelete?()
        default:
            super.keyDown(with: event)
        }
    }
}
