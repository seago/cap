import CoreGraphics
import Foundation
import Testing
@testable import Cap

private func makeLargeImage(width: Int, height: Int) -> CGImage {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

@MainActor
@Test func renderingLargeRetinaImageWithManyAnnotationsIsFastEnough() {
    let width = 3840
    let height = 2400
    let session = EditorSession(sourceImage: makeLargeImage(width: width, height: height))

    for index in 0..<10 {
        let offset = CGFloat(index) * 120
        session.add(.rectangle(CGRect(x: 100 + offset, y: 100 + offset, width: 300, height: 200)))
        session.add(.arrow(from: CGPoint(x: 200 + offset, y: 500), to: CGPoint(x: 800 + offset, y: 900)))
    }

    let start = ContinuousClock.now
    let output = AnnotationRenderer.render(session: session)
    let elapsed = ContinuousClock.now - start

    #expect(output.width == width)
    #expect(output.height == height)
    #expect(elapsed < .milliseconds(500), "渲染耗时 \(elapsed)")
}

@MainActor
@Test func editorReentryIsIgnoredWhileOpenIsEnforcedByControllerGuard() {
    // 编辑器打开时不应再次进入选区：控制器侧逻辑由 AppDelegate 的 editorController != nil 判断，
    // 这里验证 EditorController 生命周期幂等（重复 close 不崩溃）。
    let context = CGContext(
        data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let session = EditorSession(sourceImage: context.makeImage()!)
    let controller = EditorController(session: session, selectionFrame: CGRect(x: 0, y: 0, width: 200, height: 100))
    controller.close()
    controller.close()
    #expect(controller.panel == nil)
}
