import CoreGraphics
import Foundation

/// 编辑器会话：底图 + 裁剪 + 标注 + 撤销/重做。
///
/// - 所有坐标是原图像素坐标。
/// - 撤销采用快照栈：每次有效变更前保存一份快照，保证序号计数、裁剪都能回滚。
@MainActor
final class EditorSession {
    /// 底图（未标注的原图）。
    let sourceImage: CGImage
    /// 底图像素尺寸。
    let imageSize: CGSize

    private(set) var cropRect: CGRect?
    private(set) var annotations: [Annotation] = []
    private(set) var nextNumber = 1
    private(set) var isAnnotated = false

    var style: AnnotationStyle = .default
    var tool: EditorTool = .rectangle

    private struct Snapshot: Equatable {
        var cropRect: CGRect?
        var annotations: [Annotation]
        var nextNumber: Int
    }

    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []

    /// 撤销栈上限，防止长时间编辑占用过多内存。
    static let maximumUndoDepth = 50

    init(sourceImage: CGImage) {
        self.sourceImage = sourceImage
        self.imageSize = CGSize(width: sourceImage.width, height: sourceImage.height)
    }

    // MARK: - 尺寸

    /// 输出尺寸 = 裁剪尺寸（没有裁剪就是原图）。
    var outputSize: CGSize {
        cropRect?.size ?? imageSize
    }

    /// 当前可见底图区域（像素坐标）。
    var visibleRect: CGRect {
        CGRect(origin: .zero, size: imageSize)
    }

    // MARK: - 变更

    /// 添加一条标注。
    @discardableResult
    func add(_ kind: AnnotationKind) -> Annotation {
        let annotation = Annotation(kind: kind, style: style)
        mutate {
            annotations.append(annotation)
            if case .number = kind {
                nextNumber += 1
            }
        }
        isAnnotated = true
        return annotation
    }

    /// 放置序号，自动取当前计数。
    @discardableResult
    func addNumber(at center: CGPoint) -> Annotation {
        add(.number(value: nextNumber, center: center))
    }

    /// 删除最后一条标注。
    @discardableResult
    func deleteLast() -> Annotation? {
        guard let last = annotations.last else { return nil }
        mutate { annotations.removeLast() }
        return last
    }

    /// 应用裁剪（像素坐标）。只保留落在底图内的部分。
    @discardableResult
    func applyCrop(_ rect: CGRect) -> Bool {
        let clamped = rect.intersection(CGRect(origin: .zero, size: imageSize)).integral
        guard clamped.width >= 1, clamped.height >= 1 else { return false }
        mutate {
            cropRect = clamped
        }
        isAnnotated = true
        return true
    }

    // MARK: - 撤销 / 重做

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var undoDepth: Int { undoStack.count }

    @discardableResult
    func undo() -> Bool {
        guard let snapshot = undoStack.popLast() else { return false }
        redoStack.append(currentSnapshot())
        restore(snapshot)
        return true
    }

    @discardableResult
    func redo() -> Bool {
        guard let snapshot = redoStack.popLast() else { return false }
        undoStack.append(currentSnapshot())
        restore(snapshot)
        return true
    }

    // MARK: - 内部

    private func currentSnapshot() -> Snapshot {
        Snapshot(cropRect: cropRect, annotations: annotations, nextNumber: nextNumber)
    }

    private func restore(_ snapshot: Snapshot) {
        cropRect = snapshot.cropRect
        annotations = snapshot.annotations
        nextNumber = snapshot.nextNumber
        isAnnotated = !annotations.isEmpty || cropRect != nil
    }

    private func mutate(_ body: () -> Void) {
        let before = currentSnapshot()
        body()
        guard currentSnapshot() != before else { return }
        undoStack.append(before)
        if undoStack.count > Self.maximumUndoDepth {
            undoStack.removeFirst(undoStack.count - Self.maximumUndoDepth)
        }
        redoStack.removeAll()
    }
}

extension AnnotationKind {
    /// 便于测试与统计读取的种类名。
    var toolName: String {
        switch self {
        case .rectangle: return "rectangle"
        case .arrow: return "arrow"
        case .line: return "line"
        case .text: return "text"
        case .pen: return "pen"
        case .highlight: return "highlight"
        case .mosaic: return "mosaic"
        case .number: return "number"
        }
    }
}
