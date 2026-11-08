import CoreGraphics
import Foundation

/// 标注颜色（渲染层映射为具体色值，模型不依赖 AppKit）。
enum AnnotationColor: String, CaseIterable, Codable, Sendable {
    case red
    case yellow
    case blue
}

/// 标注样式：颜色 + 线宽。
struct AnnotationStyle: Equatable, Sendable {
    var color: AnnotationColor = .red
    var lineWidth: CGFloat = 4

    static let `default` = AnnotationStyle()

    static let minimumLineWidth: CGFloat = 2
    static let maximumLineWidth: CGFloat = 12

    func clampedLineWidth() -> CGFloat {
        min(max(lineWidth, Self.minimumLineWidth), Self.maximumLineWidth)
    }
}

/// 标注种类。所有坐标都是**原图像素坐标**（不是屏幕 point）。
enum AnnotationKind: Equatable, Sendable {
    case rectangle(CGRect)
    case arrow(from: CGPoint, to: CGPoint)
    case line(from: CGPoint, to: CGPoint)
    case text(String, origin: CGPoint, fontSize: CGFloat)
    case pen(points: [CGPoint])
    case highlight(CGRect)
    case mosaic(CGRect)
    case number(value: Int, center: CGPoint)
}

/// 一条标注：种类 + 样式。
struct Annotation: Equatable, Sendable, Identifiable {
    let id: UUID
    var kind: AnnotationKind
    var style: AnnotationStyle

    init(id: UUID = UUID(), kind: AnnotationKind, style: AnnotationStyle = .default) {
        self.id = id
        self.kind = kind
        self.style = style
    }

    /// 便于测试与统计读取的种类名。
    var toolName: String { kind.toolName }
}

/// 编辑器工具（标准组，顺序与工具条一致）。
enum EditorTool: String, CaseIterable, Sendable {
    case close
    case crop
    case rectangle
    case arrow
    case line
    case text
    case pen
    case highlight
    case mosaic
    case number
    case undo
    case redo
    case complete
    case save

    /// 是否是需要拖拽/单击画布的绘制工具。
    var isDrawingTool: Bool {
        switch self {
        case .rectangle, .arrow, .line, .pen, .highlight, .mosaic, .number, .text, .crop:
            return true
        case .close, .undo, .redo, .complete, .save:
            return false
        }
    }
}
