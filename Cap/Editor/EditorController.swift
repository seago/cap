import AppKit
import CoreGraphics

/// 编辑器：冻结面板 + 工具条 + 画布。
///
/// 输出回调由 AppDelegate 注入：
/// - `onFinish`：Enter / ⌘C / 「完成」——复制标注版并关闭
/// - `onSave`：⌘S / 「保存」——保存标注版并关闭
/// - `onCancel`：Esc / 「关闭」——保留原图并关闭
@MainActor
final class EditorController {
    let session: EditorSession
    let selectionFrame: CGRect

    private(set) var panel: EditorPanelWindow?
    private(set) var toolbar: EditorToolbarWindow?
    private(set) var canvas: EditorCanvasView?

    var onFinish: ((CGImage) -> Void)?
    var onSave: ((CGImage) -> Void)?
    var onCancel: (() -> Void)?
    /// 把当前渲染结果贴到屏幕（#30）。
    var onPin: ((CGImage) -> Void)?
    /// 上传当前标注结果（#31）。
    var onUpload: ((CGImage) -> Void)?
    var onToolChanged: ((EditorTool) -> Void)?

    private var toolButtons: [EditorTool: NSButton] = [:]
    private var colorButtons: [AnnotationColor: NSButton] = [:]
    private let textEditing = TextEditingController()
    private var keyMonitor: Any?

    init(session: EditorSession, selectionFrame: CGRect) {
        self.session = session
        self.selectionFrame = selectionFrame
    }

    // MARK: - 显示

    func present() {
        guard panel == nil else { return }

        let canvas = EditorCanvasView(session: session)
        canvas.frame = CGRect(origin: .zero, size: selectionFrame.size)
        canvas.onKeyDown = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }
        canvas.onCommit = { [weak self] kind in
            guard let self else { return }
            if case .number(_, let center) = kind {
                self.session.addNumber(at: center)
            } else {
                self.session.add(kind)
            }
            self.canvas?.refresh()
        }
        canvas.onCrop = { [weak self] rect in
            guard let self else { return }
            if self.session.applyCrop(rect) {
                self.canvas?.refresh()
            }
        }
        canvas.onRequestText = { [weak self] imagePoint in
            self?.beginTextInput(at: imagePoint)
        }
        self.canvas = canvas

        let panel = EditorPanelWindow(frame: selectionFrame)
        panel.contentView = canvas
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        let toolbarContent = makeToolbarContentView()
        let layoutSize = toolbarContent.fittingSize

        let toolbar = EditorToolbarWindow(contentSize: layoutSize)
        toolbar.contentView = toolbarContent
        self.toolbar = toolbar

        let visibleFrame = NSScreen.screens.first(where: { $0.frame.intersects(selectionFrame) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? selectionFrame
        let origin = ToolbarLayout.origin(
            toolbarSize: layoutSize,
            selectionFrame: selectionFrame,
            visibleFrame: visibleFrame
        )
        toolbar.setFrame(CGRect(origin: origin, size: layoutSize), display: false)
        toolbar.orderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
        canvas.window?.makeFirstResponder(canvas)
        installKeyMonitor()
        Log.editor.notice("Editor presented frame=\(String(describing: self.selectionFrame), privacy: .public)")
    }

    func close() {
        removeKeyMonitor()
        textEditing.cancel()
        toolbar?.orderOut(nil)
        toolbar?.close()
        toolbar = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        canvas = nil
    }

    // 编辑器可见期间的快捷键：不依赖 first responder，工具条点击后也稳定生效。
    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // 文字输入中不拦截，交给 NSTextField 处理。
            if self.textEditing.isEditing { return event }
            return self.handleKeyDown(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    // MARK: - 动作

    func selectTool(_ tool: EditorTool) {
        switch tool {
        case .close:
            cancel()
        case .complete:
            finish()
        case .save:
            save()
        case .undo:
            session.undo()
            canvas?.refresh()
        case .redo:
            session.redo()
            canvas?.refresh()
        default:
            session.tool = tool
            updateToolSelection()
            onToolChanged?(tool)
        }
    }

    func undo() {
        session.undo()
        canvas?.refresh()
    }

    func redo() {
        session.redo()
        canvas?.refresh()
    }

    func finish() {
        let image = AnnotationRenderer.render(session: session)
        let callback = onFinish
        close()
        callback?(image)
    }

    func save() {
        let image = AnnotationRenderer.render(session: session)
        let callback = onSave
        close()
        callback?(image)
    }

    func cancel() {
        let callback = onCancel
        close()
        callback?()
    }

    /// 把当前标注结果钉到屏幕，编辑器保持打开。
    func pin() {
        let image = AnnotationRenderer.render(session: session)
        onPin?(image)
    }

    /// 上传当前标注结果，编辑器保持打开。
    func upload() {
        let image = AnnotationRenderer.render(session: session)
        onUpload?(image)
    }

    /// 文字工具：把像素坐标换算成视图坐标，叠一个输入框。
    private func restoreCanvasFocus() {
        if let canvas {
            canvas.window?.makeFirstResponder(canvas)
        }
    }

    private func beginTextInput(at imagePoint: CGPoint) {
        guard let canvas else { return }
        let viewPoint = CGPoint(
            x: imagePoint.x * canvas.bounds.width / max(session.imageSize.width, 1),
            y: imagePoint.y * canvas.bounds.height / max(session.imageSize.height, 1)
        )
        let nsColor: NSColor
        switch session.style.color {
        case .red: nsColor = .systemRed
        case .yellow: nsColor = .systemYellow
        case .blue: nsColor = .systemBlue
        }

        textEditing.onCommit = { [weak self] text, origin, fontSize in
            guard let self else { return }
            self.session.add(.text(text, origin: origin, fontSize: fontSize))
            self.restoreCanvasFocus()
            self.canvas?.refresh()
        }
        textEditing.onCancel = { [weak self] in
            self?.restoreCanvasFocus()
            self?.canvas?.refresh()
        }
        textEditing.begin(
            in: canvas,
            atViewPoint: viewPoint,
            imagePoint: imagePoint,
            fontSize: 22,
            color: nsColor
        )
    }

    // MARK: - 键盘

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCommand = modifiers.contains(.command)
        let hasShift = modifiers.contains(.shift)

        switch event.keyCode {
        case 53: // Esc
            cancel()
            return true
        case 36, 76: // Return / Enter
            if hasCommand {
                finish()
            } else {
                finish()
            }
            return true
        case 51, 117: // Delete / Forward delete
            session.deleteLast()
            canvas?.refresh()
            return true
        case 6 where hasCommand: // ⌘Z
            if hasShift { redo() } else { undo() }
            return true
        case 1 where hasCommand: // ⌘S
            save()
            return true
        case 17 where hasCommand: // ⌘T
            pin()
            return true
        case 8 where hasCommand: // ⌘C
            finish()
            return true
        default:
            return false
        }
    }

    // MARK: - 工具条

    private func makeToolbarContentView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        stack.wantsLayer = true
        stack.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor
        stack.layer?.cornerRadius = 10

        let toolSymbols: [(EditorTool, String, String)] = [
            (.close, "xmark", String(localized: "关闭")),
            (.crop, "crop", String(localized: "裁剪")),
            (.rectangle, "rectangle", String(localized: "矩形")),
            (.arrow, "arrow.up.right", String(localized: "箭头")),
            (.line, "minus", String(localized: "直线")),
            (.text, "textformat", String(localized: "文字")),
            (.pen, "pencil.tip", String(localized: "画笔")),
            (.highlight, "highlighter", String(localized: "高亮")),
            (.mosaic, "squareshape.split.3x3", String(localized: "马赛克")),
            (.number, "1.circle", String(localized: "序号")),
        ]

        for (tool, symbol, tooltip) in toolSymbols {
            let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip) ?? NSImage(), target: self, action: #selector(toolButtonTapped(_:)))
            button.bezelStyle = .texturedRounded
            button.toolTip = tooltip
            button.identifier = NSUserInterfaceItemIdentifier(tool.rawValue)
            button.setButtonType(.toggle)
            toolButtons[tool] = button
            stack.addArrangedSubview(button)
        }

        stack.addArrangedSubview(NSBox.separator())

        for color in AnnotationColor.allCases {
            let button = NSButton(title: "", target: self, action: #selector(colorButtonTapped(_:)))
            button.bezelStyle = .circular
            button.identifier = NSUserInterfaceItemIdentifier(color.rawValue)
            button.image = colorSwatchImage(for: color)
            button.imagePosition = .imageOnly
            colorButtons[color] = button
            stack.addArrangedSubview(button)
        }

        let slider = NSSlider(value: Double(session.style.lineWidth), minValue: Double(AnnotationStyle.minimumLineWidth), maxValue: Double(AnnotationStyle.maximumLineWidth), target: self, action: #selector(widthChanged(_:)))
        slider.controlSize = .small
        slider.frame.size.width = 90
        stack.addArrangedSubview(slider)

        stack.addArrangedSubview(NSBox.separator())

        let undoButton = NSButton(image: NSImage(systemSymbolName: "arrow.uturn.backward", accessibilityDescription: String(localized: "撤销")) ?? NSImage(), target: self, action: #selector(undoTapped))
        undoButton.bezelStyle = .texturedRounded
        undoButton.toolTip = String(localized: "撤销 ⌘Z")
        stack.addArrangedSubview(undoButton)

        let redoButton = NSButton(image: NSImage(systemSymbolName: "arrow.uturn.forward", accessibilityDescription: String(localized: "重做")) ?? NSImage(), target: self, action: #selector(redoTapped))
        redoButton.bezelStyle = .texturedRounded
        redoButton.toolTip = String(localized: "重做 ⇧⌘Z")
        stack.addArrangedSubview(redoButton)

        stack.addArrangedSubview(NSBox.separator())

        let pinButton = NSButton(image: NSImage(systemSymbolName: "pin", accessibilityDescription: String(localized: "贴到屏幕")) ?? NSImage(), target: self, action: #selector(pinTapped))
        pinButton.bezelStyle = .texturedRounded
        pinButton.toolTip = String(localized: "贴到屏幕 ⌘T")
        stack.addArrangedSubview(pinButton)

        let uploadButton = NSButton(image: NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: String(localized: "上传")) ?? NSImage(), target: self, action: #selector(uploadTapped))
        uploadButton.bezelStyle = .texturedRounded
        uploadButton.toolTip = String(localized: "上传并复制链接")
        stack.addArrangedSubview(uploadButton)

        let completeButton = NSButton(image: NSImage(systemSymbolName: "checkmark", accessibilityDescription: String(localized: "完成")) ?? NSImage(), target: self, action: #selector(completeTapped))
        completeButton.bezelStyle = .texturedRounded
        completeButton.toolTip = String(localized: "完成并复制 Enter")
        stack.addArrangedSubview(completeButton)

        let saveButton = NSButton(image: NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: String(localized: "保存")) ?? NSImage(), target: self, action: #selector(saveTapped))
        saveButton.bezelStyle = .texturedRounded
        saveButton.toolTip = String(localized: "保存 ⌘S")
        stack.addArrangedSubview(saveButton)

        stack.layoutSubtreeIfNeeded()
        updateToolSelection()
        updateColorSelection()
        return stack
    }

    private func colorSwatchImage(for color: AnnotationColor) -> NSImage {
        let nsColor: NSColor
        switch color {
        case .red: nsColor = .systemRed
        case .yellow: nsColor = .systemYellow
        case .blue: nsColor = .systemBlue
        }
        let image = NSImage(size: CGSize(width: 14, height: 14))
        image.lockFocus()
        nsColor.setFill()
        NSBezierPath(ovalIn: CGRect(x: 1, y: 1, width: 12, height: 12)).fill()
        image.unlockFocus()
        return image
    }

    private func updateToolSelection() {
        for (tool, button) in toolButtons {
            let isDrawingTool = tool.isDrawingTool
            button.state = (isDrawingTool && tool == session.tool) ? .on : .off
        }
    }

    private func updateColorSelection() {
        for (color, button) in colorButtons {
            button.state = (color == session.style.color) ? .on : .off
        }
    }

    // MARK: - 工具条动作

    @objc private func toolButtonTapped(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let tool = EditorTool(rawValue: raw) else { return }
        selectTool(tool)
    }

    @objc private func colorButtonTapped(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let color = AnnotationColor(rawValue: raw) else { return }
        session.style.color = color
        updateColorSelection()
    }

    @objc private func widthChanged(_ sender: NSSlider) {
        session.style.lineWidth = CGFloat(sender.doubleValue)
    }

    @objc private func undoTapped() { undo() }
    @objc private func redoTapped() { redo() }
    @objc private func pinTapped() { pin() }
    @objc private func uploadTapped() { upload() }
    @objc private func completeTapped() { finish() }
    @objc private func saveTapped() { save() }
}

private extension NSBox {
    static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}
