import CoreGraphics

/// 工具条定位：优先放在选区下方 8pt，下方空间不足翻到上方，再不足则夹到屏幕可见区域。
enum ToolbarLayout {
    static let gap: CGFloat = 8

    /// 计算工具条窗口原点（AppKit 屏幕坐标，左下原点）。
    static func origin(
        toolbarSize: CGSize,
        selectionFrame: CGRect,
        visibleFrame: CGRect
    ) -> CGPoint {
        let x = clampX(selectionFrame: selectionFrame, toolbarWidth: toolbarSize.width, visibleFrame: visibleFrame)

        let belowY = selectionFrame.minY - gap - toolbarSize.height
        if belowY >= visibleFrame.minY {
            return CGPoint(x: x, y: belowY)
        }

        let aboveY = selectionFrame.maxY + gap
        if aboveY + toolbarSize.height <= visibleFrame.maxY {
            return CGPoint(x: x, y: aboveY)
        }

        // 上下都放不下：贴到可见区域顶部，保证工具条完整可见。
        let clampedY = min(
            max(belowY, visibleFrame.minY),
            visibleFrame.maxY - toolbarSize.height
        )
        return CGPoint(x: x, y: clampedY)
    }

    private static func clampX(selectionFrame: CGRect, toolbarWidth: CGFloat, visibleFrame: CGRect) -> CGFloat {
        let preferred = selectionFrame.midX - toolbarWidth / 2
        let maximum = visibleFrame.maxX - toolbarWidth
        return min(max(preferred, visibleFrame.minX), max(visibleFrame.minX, maximum))
    }
}
