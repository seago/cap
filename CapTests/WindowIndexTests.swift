import CoreGraphics
import Foundation
import Testing
@testable import Cap

private func window(
    id: CGWindowID,
    pid: pid_t = 100,
    layer: Int = 0,
    bounds: CGRect,
    alpha: CGFloat = 1
) -> WindowInfo {
    WindowInfo(windowID: id, ownerPID: pid, layer: layer, bounds: bounds, alpha: alpha)
}

@Test func filteringExcludesOwnProcessNonZeroLayerAndInvisible() {
    let own: pid_t = 42
    let candidates = [
        window(id: 1, pid: own, bounds: CGRect(x: 0, y: 0, width: 500, height: 500)),
        window(id: 2, layer: 25, bounds: CGRect(x: 0, y: 0, width: 500, height: 500)),
        window(id: 3, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), alpha: 0.01),
        window(id: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 500)),
        window(id: 5, bounds: CGRect(x: 10, y: 10, width: 100, height: 100)),
    ]

    let index = WindowIndex.filtered(from: candidates, ownPID: own)
    #expect(index.windows.map { $0.windowID } == [5])
}

@Test func hitTestReturnsTopmostWindow() {
    // 列表顺序即 z-order：前面的窗口在上层。
    let index = WindowIndex(windows: [
        window(id: 11, bounds: CGRect(x: 100, y: 100, width: 200, height: 200)),
        window(id: 10, bounds: CGRect(x: 0, y: 0, width: 800, height: 600)),
    ])

    #expect(index.hitTest(at: CGPoint(x: 150, y: 150))?.windowID == 11)
    #expect(index.hitTest(at: CGPoint(x: 700, y: 500))?.windowID == 10)
}

@Test func hitTestMissesEmptySpace() {
    let index = WindowIndex(windows: [
        window(id: 10, bounds: CGRect(x: 0, y: 0, width: 100, height: 100)),
    ])
    #expect(index.hitTest(at: CGPoint(x: 500, y: 500)) == nil)
}

@Test func coordinateConversionRoundTrips() {
    let mainHeight: CGFloat = 1200
    let screenPoint = CGPoint(x: 300, y: 200)
    let cgPoint = WindowIndex.cgPoint(fromScreenPoint: screenPoint, mainScreenHeight: mainHeight)
    #expect(cgPoint == CGPoint(x: 300, y: 1000))

    let cgRect = CGRect(x: 100, y: 200, width: 300, height: 400)
    let screenRect = WindowIndex.screenRect(fromCGRect: cgRect, mainScreenHeight: mainHeight)
    #expect(screenRect == CGRect(x: 100, y: 600, width: 300, height: 400))
}

@Test @MainActor func liveIndexExcludesCapItself() {
    // 真实运行环境：Cap 自己的窗口不应出现在命中列表里。
    let index = WindowIndex.loadCurrent()
    let ownPID = ProcessInfo.processInfo.processIdentifier
    #expect(index.windows.allSatisfy { $0.ownerPID != ownPID })
}
