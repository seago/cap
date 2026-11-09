import CoreGraphics
import Testing
@testable import Cap

// MARK: - 合成图

/// 生成 300x3000 的确定性条纹图（每行颜色唯一，便于逐像素比对）。
private func makeTallImage(width: Int = 320, height: Int = 3000) -> CGImage {
    let bytesPerRow = width * 4
    var data = [UInt8](repeating: 0, count: bytesPerRow * height)
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * bytesPerRow + x * 4
            data[offset] = UInt8((y * 7 + x * 3) % 256)
            data[offset + 1] = UInt8((y * 13 + x * 5) % 256)
            data[offset + 2] = UInt8((y / 3 + x * 11) % 256)
            data[offset + 3] = 255
        }
    }
    let context = CGContext(
        data: &data,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
}

@MainActor
private func frame(of tall: CGImage, offset: Int, height: Int = 800) -> CGImage {
    tall.cropping(to: CGRect(x: 0, y: offset, width: tall.width, height: height))!
}

private func pixels(of image: CGImage) -> [UInt8] {
    let width = image.width
    let height = image.height
    var data = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(
        data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return data
}

private let frameHeight = 800
private let tallHeight = 3000
private let region = CGRect(x: 100, y: 400, width: 320, height: CGFloat(frameHeight))

@MainActor
private func makeController(
    tall: CGImage,
    maximumFrames: Int = 12,
    scrollRatio: CGFloat = 0.55,
    noScroll: Bool = false,
    accessibility: Bool = true,
    onScroll: ((Int) -> Void)? = nil,
    providerOverride: (@MainActor (CGRect) async throws -> CGImage)? = nil
) -> (ScrollCaptureController, () -> Int) {
    final class OffsetBox {
        var offset = 0
    }
    let box = OffsetBox()
    let maxOffset = tallHeight - frameHeight
    let step = Int(CGFloat(frameHeight) * scrollRatio)

    let controller = ScrollCaptureController(
        configuration: .init(maximumFrames: maximumFrames, scrollRatio: scrollRatio, settleMilliseconds: 0),
        frameProvider: providerOverride ?? { _ in
            frame(of: tall, offset: box.offset)
        },
        scrollAction: { _, points, _ in
            if noScroll { return }
            let requested = Int(points)
            box.offset = min(maxOffset, box.offset + (requested > 0 ? requested : step))
            onScroll?(box.offset)
        },
        accessibilityCheck: { accessibility },
        sleep: { _ in }
    )
    return (controller, { box.offset })
}

@MainActor
@Test func scrollCaptureStitchesTallImage() async {
    let tall = makeTallImage()
    let (controller, _) = makeController(tall: tall)
    let result = await controller.run(region: region, targetPID: 1, scrollLocation: .zero)

    guard case .success(let image) = result else {
        Issue.record("expected success, got \(result)")
        return
    }
    // 每步滚动 800*0.55 = 440，到 2200 封底：总高 = 800 + 5*440 = 3000
    #expect(image.height == 3000)
    #expect(image.width == 320)

    let stitched = pixels(of: image)
    let original = pixels(of: tall)
    #expect(stitched == original)
}

@MainActor
@Test func noScrollReturnsNoScrollableContent() async {
    let tall = makeTallImage()
    let (controller, _) = makeController(tall: tall, noScroll: true)
    let result = await controller.run(region: region, targetPID: 1, scrollLocation: .zero)
    #expect(result == .failure(.noScrollableContent))
}

@MainActor
@Test func noScrollWithoutAccessibilityReportsPermission() async {
    let tall = makeTallImage()
    let (controller, _) = makeController(tall: tall, noScroll: true, accessibility: false)
    let result = await controller.run(region: region, targetPID: 1, scrollLocation: .zero)
    #expect(result == .failure(.accessibilityPermissionRequired))
}

@MainActor
@Test func maxFramesCapsCapture() async {
    let tall = makeTallImage(height: 20000)
    var captured = 0
    let maxOffset = 20000 - frameHeight
    final class Box { var offset = 0 }
    let box = Box()
    let controller = ScrollCaptureController(
        configuration: .init(maximumFrames: 5, scrollRatio: 0.2, settleMilliseconds: 0),
        frameProvider: { _ in
            captured += 1
            return frame(of: tall, offset: box.offset)
        },
        scrollAction: { _, points, _ in
            box.offset = min(maxOffset, box.offset + Int(points))
        },
        accessibilityCheck: { true },
        sleep: { _ in }
    )
    let result = await controller.run(region: region, targetPID: 1, scrollLocation: .zero)
    if case .success(let image) = result {
        #expect(captured == 5)
        // 800 + 4*160 = 1440
        #expect(image.height == 1440)
    } else {
        Issue.record("expected success, got \(result)")
    }
}

@MainActor
@Test func cancelStopsCapture() async {
    let tall = makeTallImage(height: 20000)
    final class Box { var offset = 0; weak var controller: ScrollCaptureController? }
    let box = Box()
    let controller = ScrollCaptureController(
        configuration: .init(maximumFrames: 20, scrollRatio: 0.2, settleMilliseconds: 0),
        frameProvider: { _ in frame(of: tall, offset: box.offset) },
        scrollAction: { _, points, _ in
            if box.offset > 400 { box.controller?.cancel() }
            box.offset = min(20000 - frameHeight, box.offset + Int(points))
        },
        accessibilityCheck: { true },
        sleep: { _ in }
    )
    box.controller = controller
    let result = await controller.run(region: region, targetPID: 1, scrollLocation: .zero)
    #expect(result == .failure(.cancelled))
}

@MainActor
@Test func captureFailureKeepsPartialContent() async {
    let tall = makeTallImage()
    final class Box { var offset = 0; var calls = 0 }
    let box = Box()
    let controller = ScrollCaptureController(
        configuration: .init(maximumFrames: 10, scrollRatio: 0.55, settleMilliseconds: 0),
        frameProvider: { _ in
            box.calls += 1
            if box.calls >= 3 { throw CancellationError() }
            return frame(of: tall, offset: box.offset)
        },
        scrollAction: { _, points, _ in
            box.offset = min(tallHeight - frameHeight, box.offset + Int(points))
        },
        accessibilityCheck: { true },
        sleep: { _ in }
    )
    let result = await controller.run(region: region, targetPID: 1, scrollLocation: .zero)
    if case .success(let image) = result {
        #expect(image.height >= frameHeight + 400)
    } else {
        Issue.record("expected partial success, got \(result)")
    }
}

@MainActor
@Test func alreadyRunningIsRejected() async {
    let tall = makeTallImage()
    final class Box { weak var controller: ScrollCaptureController?; var todo = true }
    let box = Box()
    let controller = ScrollCaptureController(
        configuration: .init(maximumFrames: 3, scrollRatio: 0.2, settleMilliseconds: 0),
        frameProvider: { _ in
            if box.todo {
                box.todo = false
                // 第一次运行时尝试重入
                let nested = await box.controller?.run(region: region, targetPID: 1, scrollLocation: .zero)
                #expect(nested == .failure(.alreadyRunning))
            }
            return frame(of: tall, offset: 0)
        },
        scrollAction: { _, _, _ in },
        accessibilityCheck: { true },
        sleep: { _ in }
    )
    box.controller = controller
    _ = await controller.run(region: region, targetPID: 1, scrollLocation: .zero)
}
