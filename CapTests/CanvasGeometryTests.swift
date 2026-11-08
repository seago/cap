import CoreGraphics
import Testing
@testable import Cap

private let viewSize = CGSize(width: 400, height: 300)
private let imageSize = CGSize(width: 800, height: 600)

@Test func imagePointScalesByRetinaFactor() {
    let point = CanvasGeometry.imagePoint(viewPoint: CGPoint(x: 100, y: 50), viewSize: viewSize, imageSize: imageSize)
    #expect(point == CGPoint(x: 200, y: 100))
}

@Test func imagePointIsZeroForEmptyView() {
    let point = CanvasGeometry.imagePoint(viewPoint: CGPoint(x: 10, y: 10), viewSize: .zero, imageSize: imageSize)
    #expect(point == .zero)
}

@Test func imageRectNormalizesAnyDirection() {
    let fromTopLeft = CanvasGeometry.imageRect(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 110, y: 120), viewSize: viewSize, imageSize: imageSize)
    let fromBottomRight = CanvasGeometry.imageRect(from: CGPoint(x: 110, y: 120), to: CGPoint(x: 10, y: 20), viewSize: viewSize, imageSize: imageSize)
    #expect(fromTopLeft == fromBottomRight)
    #expect(fromTopLeft == CGRect(x: 20, y: 40, width: 200, height: 200))
}

@Test func viewRectMapsBack() {
    let rect = CanvasGeometry.viewRect(from: CGRect(x: 200, y: 100, width: 400, height: 200), viewSize: viewSize, imageSize: imageSize)
    #expect(rect == CGRect(x: 100, y: 50, width: 200, height: 100))
}

@Test func dragDraftBuildsShapeForEveryDragTool() {
    let start = CGPoint(x: 10, y: 20)
    let current = CGPoint(x: 60, y: 80)

    #expect(AnnotationDraft.dragDraft(tool: .rectangle, start: start, current: current, penPoints: []) == .rectangle(CGRect(x: 10, y: 20, width: 50, height: 60)))
    #expect(AnnotationDraft.dragDraft(tool: .highlight, start: start, current: current, penPoints: []) == .highlight(CGRect(x: 10, y: 20, width: 50, height: 60)))
    #expect(AnnotationDraft.dragDraft(tool: .mosaic, start: start, current: current, penPoints: []) == .mosaic(CGRect(x: 10, y: 20, width: 50, height: 60)))
    #expect(AnnotationDraft.dragDraft(tool: .arrow, start: start, current: current, penPoints: []) == .arrow(from: start, to: current))
    #expect(AnnotationDraft.dragDraft(tool: .line, start: start, current: current, penPoints: []) == .line(from: start, to: current))
}

@Test func penDraftNeedsTwoPoints() {
    #expect(AnnotationDraft.dragDraft(tool: .pen, start: .zero, current: .zero, penPoints: [.zero]) == nil)
    let draft = AnnotationDraft.dragDraft(tool: .pen, start: .zero, current: CGPoint(x: 5, y: 5), penPoints: [.zero, CGPoint(x: 5, y: 5)])
    #expect(draft == .pen(points: [.zero, CGPoint(x: 5, y: 5)]))
}

@Test func clickToolsProduceNoDragDraft() {
    #expect(AnnotationDraft.dragDraft(tool: .number, start: .zero, current: .zero, penPoints: []) == nil)
    #expect(AnnotationDraft.dragDraft(tool: .text, start: .zero, current: .zero, penPoints: []) == nil)
    #expect(AnnotationDraft.dragDraft(tool: .crop, start: .zero, current: .zero, penPoints: []) == nil)
}

@Test func tinyShapesAreNotMeaningful() {
    #expect(AnnotationDraft.isMeaningful(.rectangle(CGRect(x: 0, y: 0, width: 0.5, height: 10))) == false)
    #expect(AnnotationDraft.isMeaningful(.rectangle(CGRect(x: 0, y: 0, width: 2, height: 10))) == true)
    #expect(AnnotationDraft.isMeaningful(.line(from: .zero, to: CGPoint(x: 0.4, y: 0))) == false)
    #expect(AnnotationDraft.isMeaningful(.pen(points: [.zero])) == false)
}
