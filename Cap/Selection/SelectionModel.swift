import CoreGraphics

/// 选区模式：拖动选区 / 单击窗口。
enum SelectionMode: Equatable, Sendable {
    case region
    case window

    var toggled: SelectionMode {
        self == .region ? .window : .region
    }
}

/// 选区结果，对应 `DESIGN.md` §5.3 的 `CaptureSource`。
enum SelectionTarget: Equatable, Sendable {
    case region(CGRect)
    case window(CGWindowID)
    case display(CGDirectDisplayID)
}

/// 一次选区会话的可变状态。
struct SelectionSession: Equatable, Sendable {
    var mode: SelectionMode = .region
    var dragStart: CGPoint?
    var dragCurrent: CGPoint?
    /// 当前悬停的窗口（由 WindowIndex 提供）；单击时作为窗口目标。
    var hoveredWindow: CGWindowID?

    var dragRect: CGRect? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    func dragDistance(from start: CGPoint, to current: CGPoint) -> CGFloat {
        hypot(current.x - start.x, current.y - start.y)
    }
}

/// 选区状态机：只依赖 CoreGraphics，便于单测。
///
/// 规则（`DESIGN.md` §3.2）：
/// - 拖动（位移 ≥ `clickThreshold`）= 区域
/// - 单击（位移 < `clickThreshold`）= 窗口
/// - 空格 = 切换 region / window 模式
/// - Enter = 未拖动时取鼠标所在屏全屏
/// - Esc = 取消
@MainActor
final class SelectionModel {
    static let clickThreshold: CGFloat = 3

    private(set) var session: SelectionSession?
    /// 只用于测试与日志：记录最近一次 Enter 使用的显示器。
    private(set) var lastFullscreenDisplayID: CGDirectDisplayID?

    var isActive: Bool { session != nil }
    var mode: SelectionMode { session?.mode ?? .region }

    /// 按下鼠标；开始一次会话。
    @discardableResult
    func begin(at point: CGPoint, mode: SelectionMode = .region) -> SelectionSession {
        var session = SelectionSession(mode: mode)
        session.dragStart = point
        session.dragCurrent = point
        self.session = session
        return session
    }

    /// 鼠标移动；更新当前拖动点。
    func move(to point: CGPoint) {
        guard session != nil else { return }
        session?.dragCurrent = point
    }

    /// 更新悬停窗口。
    func updateHoveredWindow(_ windowID: CGWindowID?) {
        session?.hoveredWindow = windowID
    }

    /// 空格切换模式。
    @discardableResult
    func toggleMode() -> SelectionMode? {
        guard var active = session else { return nil }
        active.mode = active.mode.toggled
        session = active
        return active.mode
    }

    /// 松开鼠标；返回截图目标。
    ///
    /// - 位移 ≥ 3pt → 区域（任意方向都归一化为正矩形）
    /// - 位移 < 3pt → 窗口（有悬停窗口时）；否则 nil
    func end(at point: CGPoint) -> SelectionTarget? {
        guard let current = session, let start = current.dragStart else { return nil }
        defer { session = nil }

        let distance = current.dragDistance(from: start, to: point)
        if distance >= Self.clickThreshold {
            var active = current
            active.dragCurrent = point
            guard let rect = active.dragRect, rect.width >= 1, rect.height >= 1 else { return nil }
            return .region(rect)
        }

        guard let windowID = current.hoveredWindow else { return nil }
        return .window(windowID)
    }

    /// Enter：未拖动时返回鼠标所在屏全屏目标。
    func fullscreenTarget(displayID: CGDirectDisplayID?) -> SelectionTarget? {
        guard let displayID else { return nil }
        if let session, let start = session.dragStart, let current = session.dragCurrent,
           session.dragDistance(from: start, to: current) >= Self.clickThreshold {
            // 拖动中按 Enter 不切全屏，避免误触。
            return nil
        }
        lastFullscreenDisplayID = displayID
        return .display(displayID)
    }

    /// Esc：取消并清空会话。
    func cancel() {
        session = nil
    }
}
