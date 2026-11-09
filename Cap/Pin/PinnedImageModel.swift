import CoreGraphics

/// 贴图钉屏的纯数据模型：原图尺寸 + 缩放；窗口几何由控制器按模型计算。
struct PinnedImageModel: Equatable {
    static let minimumScale: CGFloat = 0.1
    static let maximumScale: CGFloat = 8

    let imageSize: CGSize
    private(set) var scale: CGFloat

    init(imageSize: CGSize, scale: CGFloat = 1) {
        self.imageSize = imageSize
        self.scale = Self.clampScale(scale)
    }

    /// 窗口/画布上的显示尺寸。
    var displaySize: CGSize {
        CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    static func clampScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumScale), maximumScale)
    }

    /// 以某个锚点缩放：锚点在窗口内的相对位置保持不变。
    /// - Parameters:
    ///   - newScale: 目标缩放
    ///   - oldSize: 缩放前的显示尺寸
    ///   - currentOrigin: 缩放前的窗口原点（屏幕坐标，左下原点）
    ///   - anchorInWindow: 锚点在窗口内的坐标（左下原点）
    /// - Returns: 缩放后窗口应设置的原点
    static func anchoredOrigin(
        newScale rawNewScale: CGFloat,
        model: PinnedImageModel,
        oldSize: CGSize,
        currentOrigin: CGPoint,
        anchorInWindow: CGPoint
    ) -> CGPoint {
        let newScale = clampScale(rawNewScale)
        guard oldSize.width > 0, oldSize.height > 0 else { return currentOrigin }

        let ratioX = anchorInWindow.x / oldSize.width
        let ratioY = anchorInWindow.y / oldSize.height
        let newSize = CGSize(width: model.imageSize.width * newScale, height: model.imageSize.height * newScale)

        // 锚点屏幕位置 = currentOrigin + anchorInWindow，必须保持不变
        let screenAnchor = CGPoint(x: currentOrigin.x + anchorInWindow.x, y: currentOrigin.y + anchorInWindow.y)
        return CGPoint(
            x: screenAnchor.x - ratioX * newSize.width,
            y: screenAnchor.y - ratioY * newSize.height
        )
    }

    mutating func setScale(_ newScale: CGFloat) {
        scale = Self.clampScale(newScale)
    }

    mutating func zoom(by factor: CGFloat) {
        setScale(scale * factor)
    }
}
