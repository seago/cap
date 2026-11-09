import AppKit

/// 独立历史窗口（`DESIGN.md` §3.6 / §6.1，#23）：720×520 网格展示全部历史截图，
/// 支持预览、复制、在 Finder 中显示、删除、清空。
///
/// 从菜单栏 popover 的「全部截图」打开：`HistoryWindowController(store:).present()`。
/// 窗口复用同一个实例，`present()` 会刷新网格并把窗口置前。
@MainActor
final class HistoryWindowController: NSWindowController {
    /// `DESIGN.md` §3.6：历史窗口 720×520。
    static let defaultWindowSize = NSSize(width: 720, height: 520)

    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let topInset: CGFloat = 12
        static let bottomInset: CGFloat = 20
        static let interitemSpacing: CGFloat = 12
        static let lineSpacing: CGFloat = 14
    }

    private let store: HistoryStore
    private let clipboardWriter = ClipboardWriter()
    private let textRecognizer: TextRecognizing
    /// 把某条历史截图贴到屏幕（#30，AppDelegate 注入）。
    var onPin: ((HistoryItem) -> Void)?
    private let collectionHostView = FlippedDocumentView()
    private let scrollView = NSScrollView()
    private let headerLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let emptyStateLabel = NSTextField(labelWithString: String(localized: "暂无历史截图"))
    private lazy var clearButton = NSButton(
        title: String(localized: "清空历史…"),
        target: self,
        action: #selector(clearAllClicked)
    )

    private var items: [HistoryItem] = []
    private var itemViews: [HistoryGridItemView] = []
    private var thumbnailCache: [UUID: NSImage] = [:]
    private var previewController: HistoryPreviewWindowController?
    private var statusClearTask: Task<Void, Never>?

    init(store: HistoryStore, textRecognizer: TextRecognizing = VisionTextRecognizer()) {
        self.store = store
        self.textRecognizer = textRecognizer
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Cap 历史")
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 420, height: 320)
        super.init(window: window)
        window.delegate = self
        buildContent()
        window.center()
        observeStore()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// 刷新并显示历史窗口；已打开时复用同一个窗口置前。
    func present() {
        reloadHistory()
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // 首次显示时 scroll view 可能还没有完成布局，下一轮 runloop 再排一次网格。
        Task { [weak self] in
            self?.layoutGrid()
        }
    }

    override func showWindow(_ sender: Any?) {
        reloadHistory()
        super.showWindow(sender)
    }

    // MARK: - 构建界面

    private func buildContent() {
        guard let window else { return }

        headerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = .labelColor

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .right
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        clearButton.bezelStyle = .rounded

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)

        let header = NSStackView(views: [headerLabel, spacer, statusLabel, clearButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 10
        header.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        collectionHostView.frame = NSRect(origin: .zero, size: Self.defaultWindowSize)
        scrollView.documentView = collectionHostView

        emptyStateLabel.font = .systemFont(ofSize: 15)
        emptyStateLabel.textColor = .secondaryLabelColor
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(header)
        contentView.addSubview(scrollView)
        contentView.addSubview(emptyStateLabel)
        window.contentView = contentView

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            header.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Layout.horizontalInset),
            header.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Layout.horizontalInset),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 12),
        ])
    }

    // MARK: - 刷新

    private func observeStore() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(historyStoreDidChange),
            name: .historyStoreDidChange,
            object: nil
        )
    }

    @objc private func historyStoreDidChange(_ notification: Notification) {
        reloadHistory()
    }

    private func reloadHistory() {
        items = store.items
        thumbnailCache.removeAll()
        rebuildGrid()
        updateHeader()
        emptyStateLabel.isHidden = !items.isEmpty
        layoutGrid()
    }

    private func rebuildGrid() {
        for view in itemViews {
            view.removeFromSuperview()
        }
        itemViews = items.map { item in
            let itemView = HistoryGridItemView(item: item, thumbnail: thumbnailImage(for: item))
            itemView.onCopy = { [weak self] in self?.copyToClipboard(item) }
            itemView.onPreview = { [weak self] in self?.preview(item) }
            itemView.onRevealInFinder = { [weak self] in self?.revealInFinder(item) }
            itemView.onDelete = { [weak self] in self?.delete(item) }
            itemView.onRecognizeText = { [weak self] in self?.recognizeText(for: item) }
            itemView.onPin = { [weak self] in self?.onPin?(item) }
            return itemView
        }
        for itemView in itemViews {
            collectionHostView.addSubview(itemView)
        }
    }

    private func updateHeader() {
        headerLabel.stringValue = items.isEmpty ? String(localized: "全部截图") : String(localized: "全部截图 · \(items.count) 张")
        clearButton.isEnabled = !items.isEmpty
    }

    /// 按窗口可用宽度换行排布固定尺寸卡片。
    private func layoutGrid() {
        let fallbackWidth = window?.contentView?.bounds.width ?? Self.defaultWindowSize.width
        let availableWidth = max(scrollView.contentSize.width, fallbackWidth)
        let itemSize = HistoryGridItemView.size
        let usableWidth = max(availableWidth - Layout.horizontalInset * 2, itemSize.width)
        let columns = max(1, Int((usableWidth - itemSize.width) / (itemSize.width + Layout.interitemSpacing)) + 1)

        for (index, itemView) in itemViews.enumerated() {
            let row = index / columns
            let column = index % columns
            itemView.frame = NSRect(
                x: Layout.horizontalInset + CGFloat(column) * (itemSize.width + Layout.interitemSpacing),
                y: Layout.topInset + CGFloat(row) * (itemSize.height + Layout.lineSpacing),
                width: itemSize.width,
                height: itemSize.height
            )
        }

        let rows = itemViews.isEmpty ? 0 : (itemViews.count + columns - 1) / columns
        let contentHeight = rows == 0
            ? 0
            : Layout.topInset + CGFloat(rows) * itemSize.height
                + CGFloat(rows - 1) * Layout.lineSpacing + Layout.bottomInset
        collectionHostView.frame = NSRect(
            x: 0,
            y: 0,
            width: availableWidth,
            height: max(contentHeight, scrollView.contentSize.height)
        )
    }

    private func thumbnailImage(for item: HistoryItem) -> NSImage? {
        if let cached = thumbnailCache[item.id] {
            return cached
        }
        let url = store.thumbnailURL(for: item) ?? store.imageURL(for: item)
        guard let image = NSImage(contentsOf: url) else { return nil }
        thumbnailCache[item.id] = image
        return image
    }

    // MARK: - 操作

    private func copyToClipboard(_ item: HistoryItem) {
        guard let image = store.loadImage(for: item) else {
            showError(HistoryError.itemNotFound)
            return
        }
        do {
            try clipboardWriter.write(image)
            showStatus(String(localized: "已复制到剪贴板"))
            Log.history.notice("Copied history item \(item.id.uuidString, privacy: .public) to clipboard")
        } catch {
            showError(error)
        }
    }

    private func preview(_ item: HistoryItem) {
        guard let image = store.loadImage(for: item) else {
            showError(HistoryError.itemNotFound)
            return
        }
        previewController?.close()
        let controller = HistoryPreviewWindowController(item: item, image: image)
        controller.onClosed = { [weak self, weak controller] in
            guard let self, self.previewController === controller else { return }
            self.previewController = nil
            self.window?.makeKeyAndOrderFront(nil)
        }
        previewController = controller
        controller.present()
    }

    private func revealInFinder(_ item: HistoryItem) {
        NSWorkspace.shared.activateFileViewerSelecting([store.imageURL(for: item)])
    }

    private func delete(_ item: HistoryItem) {
        do {
            try store.delete(id: item.id)
            showStatus(String(localized: "已删除一条记录"))
            Log.history.notice("Deleted history item \(item.id.uuidString, privacy: .public)")
        } catch {
            showError(error)
        }
    }

    @objc private func clearAllClicked() {
        guard !items.isEmpty, let window else { return }
        let alert = NSAlert()
        alert.messageText = String(localized: "清空历史？")
        alert.informativeText = String(localized: "将删除全部 \(items.count) 条截图及其图片、缩略图，此操作不可撤销。")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "清空"))
        alert.addButton(withTitle: String(localized: "取消"))
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.performClearAll()
        }
    }

    private func performClearAll() {
        do {
            try store.clearAll()
            showStatus(String(localized: "已清空历史"))
            Log.history.notice("Cleared all history items")
        } catch {
            showError(error)
        }
    }

    /// 对单条历史截图做文字识别，结果复制到剪贴板并写入索引。
    private func recognizeText(for item: HistoryItem) {
        guard let image = store.loadImage(for: item) else {
            showStatus(String(localized: "图片无法读取"))
            return
        }
        showStatus(String(localized: "正在识别文字…"))
        let recognizer = textRecognizer
        let store = self.store
        let clipboardWriter = self.clipboardWriter
        let itemID = item.id
        Task { @MainActor [weak self] in
            do {
                let result = try await recognizer.recognizeText(in: image)
                guard !result.isEmpty else {
                    self?.showStatus(String(localized: "没有识别到文字"))
                    return
                }
                try clipboardWriter.writeText(result.text)
                try? store.setOCRText(id: itemID, text: result.text)
                self?.showStatus(String(localized: "已识别并复制 \(result.text.count) 个字符"))
            } catch {
                self?.showStatus(String(localized: "识别失败：\(error.localizedDescription)"))
            }
        }
    }

    private func showStatus(_ text: String) {
        statusLabel.stringValue = text
        statusClearTask?.cancel()
        statusClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.statusLabel.stringValue = ""
        }
    }

    private func showError(_ error: Error) {
        NSSound.beep()
        let alert = NSAlert()
        alert.messageText = String(localized: "操作失败")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "好"))
        if let window, window.isVisible {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}

extension HistoryWindowController: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) {
        layoutGrid()
    }

    func windowWillClose(_ notification: Notification) {
        previewController?.close()
        previewController = nil
    }
}

// MARK: - 预览窗口

/// 大图预览窗口：展示原图/标注版，适合窗口尺寸缩放；Esc 关闭。
@MainActor
private final class HistoryPreviewWindowController: NSWindowController, NSWindowDelegate {
    var onClosed: (() -> Void)?

    private static let maxContentSize = NSSize(width: 1000, height: 720)
    private static let minContentSize = NSSize(width: 360, height: 240)

    init(item: HistoryItem, image: CGImage) {
        let pixelSize = NSSize(width: max(image.width, 1), height: max(image.height, 1))
        let scale = min(
            Self.maxContentSize.width / pixelSize.width,
            Self.maxContentSize.height / pixelSize.height,
            1
        )
        let contentSize = NSSize(
            width: max(pixelSize.width * scale, Self.minContentSize.width),
            height: max(pixelSize.height * scale, Self.minContentSize.height)
        )

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        window.title = String(localized: "预览 · \(formatter.string(from: item.createdAt)) · \(item.pixelWidth)×\(item.pixelHeight) px")
        super.init(window: window)

        let contentView = PreviewContentView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.cgColor
        contentView.onCancel = { [weak self] in
            self?.close()
        }

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = NSImage(cgImage: image, size: pixelSize)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        window.contentView = contentView
        window.delegate = self
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }
        window.makeFirstResponder(window.contentView)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClosed?()
    }
}

/// 预览窗口内容视图：Esc 关闭。
@MainActor
private final class PreviewContentView: NSView {
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }
}

/// 滚动视图的文档视图，翻转坐标方便从上往下排网格。
@MainActor
private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool {
        true
    }
}
