import AppKit

/// 选区覆盖层：为每个屏幕建一个覆盖窗口，负责显示/关闭、光标跟随与 Esc 取消。
///
/// M1 阶段只做覆盖与取消；拖动/单击/空格/Enter 的完整交互在 #13。
@MainActor
final class SelectionOverlayController {
    private(set) var windows: [SelectionOverlayWindow] = []
    private(set) var canvasViews: [SelectionCanvasView] = []
    private var eventMonitor: Any?

    /// Esc 或外部取消时的回调。
    var onCancel: (() -> Void)?

    var isPresented: Bool { !windows.isEmpty }

    /// 打开覆盖层。
    func present() {
        guard !isPresented else { return }

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
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .keyDown]) { [weak self] event in
            guard let self else { return event }
            switch event.type {
            case .mouseMoved:
                self.updateCursorHole()
                return event
            case .keyDown:
                if event.keyCode == 53 { // Esc
                    self.cancel()
                    return nil
                }
                return event
            default:
                return event
            }
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    /// 把全局鼠标位置换算到每个覆盖窗口的本地坐标并重绘挖孔。
    private func updateCursorHole() {
        let location = NSEvent.mouseLocation
        for (window, canvas) in zip(windows, canvasViews) {
            guard window.frame.contains(location) else { continue }
            let local = CGPoint(
                x: location.x - window.frame.minX,
                y: location.y - window.frame.minY
            )
            canvas.updateCursorPoint(local)
        }
    }

    /// 单元测试用：直接写入光标位置。
    func setCursorPointForTesting(_ point: CGPoint, windowIndex: Int = 0) {
        guard canvasViews.indices.contains(windowIndex) else { return }
        canvasViews[windowIndex].updateCursorPoint(point)
    }

    /// 单元测试用：写入选区矩形。
    func setSelectionRectForTesting(_ rect: CGRect?, windowIndex: Int = 0) {
        guard canvasViews.indices.contains(windowIndex) else { return }
        canvasViews[windowIndex].selectionRect = rect
    }
}
