import CoreGraphics
import Testing
@testable import Cap

private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
private let toolbarSize = CGSize(width: 600, height: 44)

@Test func toolbarGoesBelowSelectionWhenSpaceAvailable() {
    let selection = CGRect(x: 400, y: 500, width: 800, height: 300)
    let origin = ToolbarLayout.origin(toolbarSize: toolbarSize, selectionFrame: selection, visibleFrame: screen)

    #expect(origin.y == selection.minY - ToolbarLayout.gap - toolbarSize.height)
    #expect(origin.x == selection.midX - toolbarSize.width / 2)
}

@Test func toolbarFlipsAboveWhenBelowHasNoSpace() {
    let selection = CGRect(x: 400, y: 10, width: 800, height: 300)
    let origin = ToolbarLayout.origin(toolbarSize: toolbarSize, selectionFrame: selection, visibleFrame: screen)

    #expect(origin.y == selection.maxY + ToolbarLayout.gap)
}

@Test func toolbarClampsIntoVisibleFrameWhenNeitherSideFits() {
    // 选区几乎占满整屏：上下都放不下
    let selection = CGRect(x: 0, y: 20, width: 1920, height: 1040)
    let origin = ToolbarLayout.origin(toolbarSize: toolbarSize, selectionFrame: selection, visibleFrame: screen)

    #expect(origin.y >= screen.minY)
    #expect(origin.y + toolbarSize.height <= screen.maxY)
}

@Test func toolbarXIsClampedToScreenEdges() {
    let leftSelection = CGRect(x: 0, y: 500, width: 100, height: 100)
    let leftOrigin = ToolbarLayout.origin(toolbarSize: toolbarSize, selectionFrame: leftSelection, visibleFrame: screen)
    #expect(leftOrigin.x >= screen.minX)

    let rightSelection = CGRect(x: 1820, y: 500, width: 100, height: 100)
    let rightOrigin = ToolbarLayout.origin(toolbarSize: toolbarSize, selectionFrame: rightSelection, visibleFrame: screen)
    #expect(rightOrigin.x + toolbarSize.width <= screen.maxX)
}

@Test func toolbarNeverOverlapsSelectionWhenBelowFits() {
    let selection = CGRect(x: 300, y: 600, width: 500, height: 200)
    let origin = ToolbarLayout.origin(toolbarSize: toolbarSize, selectionFrame: selection, visibleFrame: screen)
    let toolbarRect = CGRect(origin: origin, size: toolbarSize)
    #expect(toolbarRect.intersects(selection) == false)
}
