import CoreGraphics
import Testing
@testable import Cap

@MainActor
private func makeSession(width: Int = 200, height: Int = 100) -> EditorSession {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return EditorSession(sourceImage: context.makeImage()!)
}

@MainActor
@Test func sessionStartsWithImageSizeAndNoAnnotations() {
    let session = makeSession()
    #expect(session.imageSize == CGSize(width: 200, height: 100))
    #expect(session.outputSize == CGSize(width: 200, height: 100))
    #expect(session.annotations.isEmpty)
    #expect(session.isAnnotated == false)
}

@MainActor
@Test func allNineAnnotationKindsCanBeAdded() {
    let session = makeSession()

    session.add(.rectangle(CGRect(x: 1, y: 2, width: 10, height: 20)))
    session.add(.arrow(from: .zero, to: CGPoint(x: 5, y: 5)))
    session.add(.line(from: .zero, to: CGPoint(x: 9, y: 9)))
    session.add(.text("hi", origin: CGPoint(x: 3, y: 4), fontSize: 14))
    session.add(.pen(points: [.zero, CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 0)]))
    session.add(.highlight(CGRect(x: 5, y: 5, width: 30, height: 10)))
    session.add(.mosaic(CGRect(x: 8, y: 8, width: 12, height: 12)))
    session.addNumber(at: CGPoint(x: 40, y: 40))
    session.applyCrop(CGRect(x: 10, y: 10, width: 100, height: 50))

    #expect(session.annotations.count == 8)
    #expect(session.annotations.map { $0.toolName } == [
        "rectangle", "arrow", "line", "text", "pen", "highlight", "mosaic", "number",
    ])
    #expect(session.cropRect == CGRect(x: 10, y: 10, width: 100, height: 50))
    #expect(session.outputSize == CGSize(width: 100, height: 50))
    #expect(session.isAnnotated)
}

@MainActor
@Test func annotationCountToolNameIsAvailable() {
    // 9 种工具都可通过 toolName 识别（含 number 与 crop 之外的 8 种标注）
    let kinds: [AnnotationKind] = [
        .rectangle(.zero), .arrow(from: .zero, to: .zero), .line(from: .zero, to: .zero),
        .text("x", origin: .zero, fontSize: 12), .pen(points: [.zero]),
        .highlight(.zero), .mosaic(.zero), .number(value: 1, center: .zero),
    ]
    #expect(Set(kinds.map { $0.toolName }).count == 8)
}

@MainActor
@Test func numbersIncrementAndRollBackOnUndo() {
    let session = makeSession()
    session.addNumber(at: .zero)
    session.addNumber(at: .zero)
    #expect(session.nextNumber == 3)

    session.undo()
    #expect(session.nextNumber == 2)
    #expect(session.annotations.count == 1)

    session.addNumber(at: .zero)
    #expect(session.annotations.last?.kind == .number(value: 2, center: .zero))
    #expect(session.nextNumber == 3)
}

@MainActor
@Test func undoRedoSequenceIsStable() {
    let session = makeSession()
    session.add(.rectangle(.zero))
    session.add(.line(from: .zero, to: CGPoint(x: 1, y: 1)))
    #expect(session.annotations.count == 2)

    #expect(session.undo())
    #expect(session.annotations.count == 1)
    #expect(session.undo())
    #expect(session.annotations.isEmpty)
    #expect(session.undo() == false)

    #expect(session.redo())
    #expect(session.annotations.count == 1)
    #expect(session.redo())
    #expect(session.annotations.count == 2)
    #expect(session.redo() == false)
}

@MainActor
@Test func newEditClearsRedoStack() {
    let session = makeSession()
    session.add(.rectangle(.zero))
    session.undo()
    #expect(session.canRedo)

    session.add(.arrow(from: .zero, to: CGPoint(x: 2, y: 2)))
    #expect(session.canRedo == false)
}

@MainActor
@Test func deleteLastRemovesAndCanBeUndone() {
    let session = makeSession()
    session.add(.rectangle(.zero))
    session.add(.line(from: .zero, to: CGPoint(x: 1, y: 1)))

    let removed = session.deleteLast()
    #expect(removed?.toolName == "line")
    #expect(session.annotations.count == 1)

    session.undo()
    #expect(session.annotations.count == 2)
}

@MainActor
@Test func cropIsClampedToImageBounds() {
    let session = makeSession()
    #expect(session.applyCrop(CGRect(x: -50, y: -50, width: 100, height: 100)))
    #expect(session.cropRect == CGRect(x: 0, y: 0, width: 50, height: 50))
    #expect(session.outputSize == CGSize(width: 50, height: 50))
}

@MainActor
@Test func tinyCropIsRejected() {
    let session = makeSession()
    #expect(session.applyCrop(CGRect(x: 10, y: 10, width: 0, height: 0)) == false)
    #expect(session.cropRect == nil)
}

@MainActor
@Test func cropCanBeUndone() {
    let session = makeSession()
    session.applyCrop(CGRect(x: 10, y: 10, width: 50, height: 40))
    #expect(session.outputSize == CGSize(width: 50, height: 40))

    session.undo()
    #expect(session.cropRect == nil)
    #expect(session.outputSize == CGSize(width: 200, height: 100))
}

@MainActor
@Test func undoDepthIsCapped() {
    let session = makeSession()
    for index in 0..<(EditorSession.maximumUndoDepth + 10) {
        _ = session.add(.number(value: index + 1, center: .zero))
    }
    #expect(session.undoDepth == EditorSession.maximumUndoDepth)
}

@MainActor
@Test func styleCarriesColorAndClampedLineWidth() {
    let session = makeSession()
    session.style = AnnotationStyle(color: .blue, lineWidth: 99)
    let annotation = session.add(.line(from: .zero, to: CGPoint(x: 5, y: 5)))
    #expect(annotation.style.color == .blue)
    #expect(annotation.style.clampedLineWidth() == AnnotationStyle.maximumLineWidth)
}
