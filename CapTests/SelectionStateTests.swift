import CoreGraphics
import Testing
@testable import Cap

@MainActor
@Test func dragCreatesNormalizedRegion() {
    let model = SelectionModel()
    model.begin(at: CGPoint(x: 300, y: 400))
    model.move(to: CGPoint(x: 100, y: 150))

    let target = model.end(at: CGPoint(x: 100, y: 150))
    #expect(target == .region(CGRect(x: 100, y: 150, width: 200, height: 250)))
    #expect(model.session == nil)
}

@MainActor
@Test func dragInEveryDirectionIsNormalized() {
    let cases: [(CGPoint, CGPoint, CGRect)] = [
        (CGPoint(x: 100, y: 100), CGPoint(x: 200, y: 200), CGRect(x: 100, y: 100, width: 100, height: 100)),
        (CGPoint(x: 200, y: 100), CGPoint(x: 100, y: 200), CGRect(x: 100, y: 100, width: 100, height: 100)),
        (CGPoint(x: 100, y: 200), CGPoint(x: 200, y: 100), CGRect(x: 100, y: 100, width: 100, height: 100)),
        (CGPoint(x: 200, y: 200), CGPoint(x: 100, y: 100), CGRect(x: 100, y: 100, width: 100, height: 100)),
    ]

    for (start, end, expected) in cases {
        let model = SelectionModel()
        model.begin(at: start)
        model.move(to: end)
        #expect(model.end(at: end) == .region(expected))
    }
}

@MainActor
@Test func tinyMovementIsClickAndSelectsWindow() {
    let model = SelectionModel()
    model.begin(at: CGPoint(x: 100, y: 100))
    model.updateHoveredWindow(42)
    model.move(to: CGPoint(x: 102, y: 101))

    #expect(model.end(at: CGPoint(x: 102, y: 101)) == .window(42))
}

@MainActor
@Test func clickWithoutWindowProducesNoTarget() {
    let model = SelectionModel()
    model.begin(at: CGPoint(x: 100, y: 100))
    #expect(model.end(at: CGPoint(x: 100, y: 100)) == nil)
}

@MainActor
@Test func spaceTogglesMode() {
    let model = SelectionModel()
    model.begin(at: .zero)
    #expect(model.mode == .region)
    #expect(model.toggleMode() == .window)
    #expect(model.toggleMode() == .region)
}

@MainActor
@Test func enterReturnsDisplayWhenNotDragging() {
    let model = SelectionModel()
    model.begin(at: CGPoint(x: 10, y: 10))
    model.move(to: CGPoint(x: 11, y: 10))

    #expect(model.fullscreenTarget(displayID: 2) == .display(2))
    #expect(model.lastFullscreenDisplayID == 2)
}

@MainActor
@Test func enterDoesNotFireWhileDragging() {
    let model = SelectionModel()
    model.begin(at: .zero)
    model.move(to: CGPoint(x: 50, y: 50))

    #expect(model.fullscreenTarget(displayID: 2) == nil)
}

@MainActor
@Test func cancelClearsSession() {
    let model = SelectionModel()
    model.begin(at: .zero)
    model.move(to: CGPoint(x: 40, y: 40))
    model.cancel()
    #expect(model.isActive == false)
    #expect(model.end(at: CGPoint(x: 40, y: 40)) == nil)
}

@MainActor
@Test func dragShorterThanOnePointIsRejected() {
    let model = SelectionModel()
    model.begin(at: CGPoint(x: 10, y: 10))
    model.move(to: CGPoint(x: 13.5, y: 10))

    // 位移超过阈值但不构成 1pt 以上的矩形时不应产生区域目标。
    #expect(model.end(at: CGPoint(x: 13.5, y: 10)) == nil)
}
