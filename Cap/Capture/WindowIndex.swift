import CoreGraphics
import Foundation

/// 一个可被截图/命中的窗口，坐标使用 CoreGraphics 全局坐标（原点在主屏左上，y 向下）。
struct WindowInfo: Equatable, Sendable {
    let windowID: CGWindowID
    let ownerPID: pid_t
    let layer: Int
    let bounds: CGRect
    let alpha: CGFloat
}

/// 当前屏幕上的窗口列表，提供 z-order 命中测试。
///
/// - 顺序即 z-order：列表前面的窗口在上层。
/// - 排除：自己进程的窗口、非 0 层（菜单栏/浮层/Dock 等）、几乎透明的窗口、过小的窗口。
struct WindowIndex: Equatable, Sendable {
    /// 已过滤的窗口列表，顶层在前。
    let windows: [WindowInfo]

    static let minimumAlpha: CGFloat = 0.05
    static let minimumSize: CGFloat = 2

    init(windows: [WindowInfo]) {
        self.windows = windows
    }

    /// 从 `CGWindowListCopyWindowInfo` 结果过滤。
    static func filtered(from candidates: [WindowInfo], ownPID: pid_t) -> WindowIndex {
        let result = candidates.filter { window in
            window.ownerPID != ownPID
                && window.layer == 0
                && window.alpha >= minimumAlpha
                && window.bounds.width >= minimumSize
                && window.bounds.height >= minimumSize
        }
        return WindowIndex(windows: result)
    }

    /// 读取当前屏上窗口（只在真实运行时调用）。
    static func loadCurrent(ownPID: pid_t = ProcessInfo.processInfo.processIdentifier) -> WindowIndex {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return WindowIndex(windows: [])
        }

        let candidates: [WindowInfo] = raw.compactMap { entry in
            guard
                let windowID = entry[kCGWindowNumber as String] as? CGWindowID,
                let ownerPID = entry[kCGWindowOwnerPID as String] as? pid_t,
                let layer = entry[kCGWindowLayer as String] as? Int,
                let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
                let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { return nil }

            let alpha = entry[kCGWindowAlpha as String] as? CGFloat ?? 1
            return WindowInfo(windowID: windowID, ownerPID: ownerPID, layer: layer, bounds: bounds, alpha: alpha)
        }
        return filtered(from: candidates, ownPID: ownPID)
    }

    /// 命中测试：返回包含该点的最上层窗口。
    func hitTest(at point: CGPoint) -> WindowInfo? {
        windows.first { $0.bounds.contains(point) }
    }

    /// 把 AppKit 屏幕坐标（原点左下）转换为 CoreGraphics 全局坐标（原点左上）。
    static func cgPoint(fromScreenPoint point: CGPoint, mainScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: mainScreenHeight - point.y)
    }

    /// 把 CoreGraphics 全局矩形转换为 AppKit 屏幕坐标（原点左下）。
    static func screenRect(fromCGRect rect: CGRect, mainScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: mainScreenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
