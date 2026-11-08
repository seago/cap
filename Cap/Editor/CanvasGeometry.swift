import CoreGraphics

/// 画布坐标换算：视图坐标（点，左上原点）↔ 原图像素坐标。
enum CanvasGeometry {
    /// 视图点 → 图像像素点。
    static func imagePoint(viewPoint: CGPoint, viewSize: CGSize, imageSize: CGSize) -> CGPoint {
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }
        let scaleX = imageSize.width / viewSize.width
        let scaleY = imageSize.height / viewSize.height
        return CGPoint(x: viewPoint.x * scaleX, y: viewPoint.y * scaleY)
    }

    /// 两个视图点 → 图像像素矩形（归一化为正矩形）。
    static func imageRect(from start: CGPoint, to end: CGPoint, viewSize: CGSize, imageSize: CGSize) -> CGRect {
        let a = imagePoint(viewPoint: start, viewSize: viewSize, imageSize: imageSize)
        let b = imagePoint(viewPoint: end, viewSize: viewSize, imageSize: imageSize)
        return CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }

    /// 图像矩形 → 视图矩形（用于裁剪后重设画布）。
    static func viewRect(from imageRect: CGRect, viewSize: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        return CGRect(
            x: imageRect.minX * scaleX,
            y: imageRect.minY * scaleY,
            width: imageRect.width * scaleX,
            height: imageRect.height * scaleY
        )
    }
}

/// 根据工具与拖拽输入生成待提交的标注。
enum AnnotationDraft {
    /// 拖拽类工具：起点 + 当前点（像素坐标）。
    static func dragDraft(
        tool: EditorTool,
        start: CGPoint,
        current: CGPoint,
        penPoints: [CGPoint]
    ) -> AnnotationKind? {
        switch tool {
        case .rectangle:
            return .rectangle(normalizedRect(start, current))
        case .highlight:
            return .highlight(normalizedRect(start, current))
        case .mosaic:
            return .mosaic(normalizedRect(start, current))
        case .arrow:
            return .arrow(from: start, to: current)
        case .line:
            return .line(from: start, to: current)
        case .pen:
            guard penPoints.count >= 2 else { return nil }
            return .pen(points: penPoints)
        default:
            return nil
        }
    }

    static func normalizedRect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }

    /// 拖拽是否达到可提交的最小尺寸（1px）。
    static func isMeaningful(_ kind: AnnotationKind) -> Bool {
        switch kind {
        case .rectangle(let rect), .highlight(let rect), .mosaic(let rect):
            return rect.width >= 1 && rect.height >= 1
        case .line(let from, let to), .arrow(let from, let to):
            return hypot(to.x - from.x, to.y - from.y) >= 1
        case .pen(let points):
            return points.count >= 2
        default:
            return true
        }
    }
}
