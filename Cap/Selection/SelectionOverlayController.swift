import AppKit

/// 选区覆盖层：为每个屏幕建一个覆盖窗口，驱动 `SelectionModel` 完成拖动 / 单击 / 空格 / Enter / Esc。
@MainActor
final class SelectionOverlayController {
    private(set) var windows: [SelectionOverlayWindow] = []
    private(set) var canvasViews: [SelectionCanvasView] = []

    private let model = SelectionModel()
    private var windowIndex = WindowIndex(windows: [])
    private var eventMonitor: Any?

    /// 选中目标后的回调：目标 + 截取选项（窗口阴影由 Option 决定）。
    var onSelect: ((SelectionTarget, CaptureOptions) -> Void)?
    /// Esc 或外部取消时的回调。
    var onCancel: (() -> Void)?

    var isPresented: Bool { !windows.isEmpty }

    /// 打开覆盖层。
    func present() {
        guard !isPresented else { return }
        refreshWindowIndex()

        for screen in NSScreen.screens {
            let window = SelectionOverlayWindow(screen: screen)
            let canvas = SelectionCanvasView(frame: CGRect(origin: .zero, size: screen.frame.size))
            canvas.autoresizingMask = [.width, .height]
            window.contentView = canvas
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
            canvasViews.append(canvas)
        }

        NSApp.activate(ignoringOtherApps: true)
        installEventMonitor()
        updateCursorHole()
    }

    /// 关闭覆盖层并清理监听。
    func dismiss() {
        removeEventMonitor()
        model.cancel()
        for window in windows {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }
        windows.removeAll()
        canvasViews.removeAll()
    }

    /// 取消当前选区。
    func cancel() {
        dismiss()
        onCancel?()
    }

    // MARK: - 事件

    private func installEventMonitor() {
        removeEventMonitor()
        let mask: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp, .keyDown,
        ]
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .mouseMoved:
            handleMouseMoved(event)
            return event
        case .leftMouseDown:
            handleMouseDown(event)
            return nil
        case .leftMouseDragged:
            handleMouseDragged(event)
            return nil
        case .leftMouseUp:
            handleMouseUp(event)
            return nil
        case .keyDown:
            return handleKeyDown(event)
        default:
            return event
        }
    }

    private func handleMouseMoved(_ event: NSEvent) {
        guard let point = screenPoint(for: event) else { return }
        updateHover(at: point)
        updateCursorHole(at: point)
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard let point = screenPoint(for: event) else { return }
        refreshWindowIndex()
        let mode: SelectionMode = event.modifierFlags.contains(.option) ? .window : .region
        model.begin(at: point, mode: mode)
        updateHover(at: point)
        redrawSelection()
    }

    private func handleMouseDragged(_ event: NSEvent) {
        guard let point = screenPoint(for: event) else { return }
        model.move(to: point)
        redrawSelection()
        updateHover(at: point)
        updateCursorHole(at: point)
    }

    private func handleMouseUp(_ event: NSEvent) {
        guard let point = screenPoint(for: event) else { return }
        let options: CaptureOptions = event.modifierFlags.contains(.option) ? .windowWithoutShadow : .windowDefault
        guard let target = model.end(at: point) else {
            redrawSelection()
            return
        }
        finish(with: target, options: options)
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 53: // Esc
            cancel()
            return nil
        case 49: // Space
            model.toggleMode()
            redrawSelection()
            return nil
        case 36, 76: // Return / Enter
            guard let displayID = ScreenCaptureService.displayUnderMouse(),
                  let target = model.fullscreenTarget(displayID: displayID) else {
                return nil
            }
            finish(with: target, options: .windowDefault)
            return nil
        default:
            return event
        }
    }

    private func finish(with target: SelectionTarget, options: CaptureOptions) {
        Log.selection.notice("Selection finished: \(String(describing: target), privacy: .public), shadow=\(options.includeWindowShadow, privacy: .public)")
        dismiss()
        onSelect?(target, options)
    }

    // MARK: - 坐标与绘制

    /// 事件所在窗口的本地坐标 → 全局 AppKit 屏幕坐标（原点主屏左下）。
    private func screenPoint(for event: NSEvent) -> CGPoint? {
        guard let window = event.window ?? windows.first else { return nil }
        let local = event.locationInWindow
        return window.convertPoint(toScreen: local)
    }

    /// 全局 AppKit 矩形 → 某覆盖窗口的本地矩形。
    private func localRect(_ rect: CGRect, in window: SelectionOverlayWindow) -> CGRect {
        rect.offsetBy(dx: -window.frame.minX, dy: -window.frame.minY)
    }

    private func redrawSelection() {
        let dragRect = model.session?.dragRect
        for (index, window) in windows.enumerated() {
            guard canvasViews.indices.contains(index) else { continue }
            let canvas = canvasViews[index]
            canvas.selectionRect = dragRect.map { localRect($0, in: window) }
            canvas.isWindowMode = model.mode == .window
        }
    }

    private func updateHover(at point: CGPoint) {
        let mainHeight = ScreenCaptureService.mainScreenHeight()
        let cgPoint = WindowIndex.cgPoint(fromScreenPoint: point, mainScreenHeight: mainHeight)
        let hit = windowIndex.hitTest(at: cgPoint)
        model.updateHoveredWindow(hit?.windowID)

        for (index, window) in windows.enumerated() {
            guard canvasViews.indices.contains(index), let hit else {
                canvasViews[safe: index]?.highlightRect = nil
                continue
            }
            let screenRect = WindowIndex.screenRect(fromCGRect: hit.bounds, mainScreenHeight: mainHeight)
            canvasViews[index].highlightRect = localRect(screenRect, in: window)
        }
    }

    private func updateCursorHole(at point: CGPoint? = nil) {
        let global = point ?? NSEvent.mouseLocation
        for (index, window) in windows.enumerated() {
            guard canvasViews.indices.contains(index), window.frame.contains(global) else { continue }
            let local = CGPoint(x: global.x - window.frame.minX, y: global.y - window.frame.minY)
            canvasViews[index].updateCursorPoint(local)
        }
    }

    private func refreshWindowIndex() {
        windowIndex = WindowIndex.loadCurrent()
    }

    // MARK: - 测试辅助

    func setCursorPointForTesting(_ point: CGPoint, windowIndex: Int = 0) {
        guard canvasViews.indices.contains(windowIndex) else { return }
        canvasViews[windowIndex].updateCursorPoint(point)
    }

    func setSelectionRectForTesting(_ rect: CGRect?, windowIndex: Int = 0) {
        guard canvasViews.indices.contains(windowIndex) else { return }
        canvasViews[windowIndex].selectionRect = rect
    }

    /// 测试辅助：模拟一次选择完成（绕过真实鼠标事件）。
    func simulateSelect(_ target: SelectionTarget, options: CaptureOptions = .windowDefault) {
        finish(with: target, options: options)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
