import CoreGraphics
import Foundation
import Testing
@testable import Cap

// MARK: - 合成图工具

private let tallWidth = 400
private let tallHeight = 3000
private let frameHeight = 600
private let scrollStep = 400

private func makeImage(width: Int, height: Int, pixels: [UInt8]) -> CGImage {
    precondition(pixels.count == width * height * 4)
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )!
}

/// 400x3000 的确定性长图：竖向渐变 + 每行唯一的噪声条纹。
/// 行与行之间足够不同，滚动偏移检测不会因为周期内容产生歧义。
private func makeTallImage(width: Int = tallWidth, height: Int = tallHeight) -> CGImage {
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    var state: UInt64 = 0x9E37_79B9_7F4A_7C15
    for y in 0..<height {
        let gradient = (y * 255) / max(height - 1, 1)
        for x in 0..<width {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let noise = Int((state >> 33) & 0x1F) - 16
            let index = (y * width + x) * 4
            pixels[index] = UInt8((gradient + x * 3 + noise + 512) % 256)
            pixels[index + 1] = UInt8((gradient / 2 + y * 5 + x * 7 + noise + 512) % 256)
            pixels[index + 2] = UInt8((255 - gradient + x * 11 + noise * 2 + 512) % 256)
            pixels[index + 3] = 255
        }
    }
    return makeImage(width: width, height: height, pixels: pixels)
}

/// 与任何长图都没有重叠的随机噪声帧。
private func makeRandomImage(width: Int, height: Int, seed: UInt64) -> CGImage {
    var state = seed &* 0x9E37_79B9_7F4A_7C15 &+ 1
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    var index = 0
    while index < pixels.count {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        pixels[index] = UInt8(truncatingIfNeeded: state >> 33)
        pixels[index + 1] = UInt8(truncatingIfNeeded: state >> 41)
        pixels[index + 2] = UInt8(truncatingIfNeeded: state >> 17)
        pixels[index + 3] = 255
        index += 4
    }
    return makeImage(width: width, height: height, pixels: pixels)
}

private func frame(of image: CGImage, offset: Int, height: Int = frameHeight) -> CGImage {
    image.cropping(to: CGRect(x: 0, y: offset, width: image.width, height: height))!
}

/// 用与拼接实现相同的 1:1 方式解码，便于逐像素比较。
private func pixels(of image: CGImage) -> [UInt8] {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
    pixels.withUnsafeMutableBytes { buffer in
        guard let baseAddress = buffer.baseAddress,
              let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            return
        }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return pixels
}

// MARK: - 拼接

@Test func stitchedFramesMatchOriginalTallImagePixels() throws {
    let tall = makeTallImage()
    let offsets = Array(stride(from: 0, through: tallHeight - frameHeight, by: scrollStep))
    let frames = offsets.map { frame(of: tall, offset: $0) }
    #expect(offsets == [0, 400, 800, 1200, 1600, 2000, 2400])
    #expect(frames.count == 7)

    var stitcher = ScrollStitcher()
    stitcher.maximumSearchDistance = 800
    let stitched = try stitcher.stitch(frames: frames)

    #expect(stitched.image.width == tallWidth)
    // 600 + 6 * 400 = 3000，正好是原始长图高度，没有重复带也没有缺行。
    #expect(stitched.image.height == tallHeight)
    #expect(stitched.frameCount == frames.count)
    #expect(pixels(of: stitched.image) == pixels(of: tall))
}

@Test func findOffsetReturnsExactScrollDistance() {
    let tall = makeTallImage()
    let previous = frame(of: tall, offset: 500)
    let next = frame(of: tall, offset: 900)

    let offset = ScrollStitcher().findOffset(previous: previous, next: next)
    #expect(offset == scrollStep)
}

@Test func identicalFramesHaveZeroOffset() throws {
    let tall = makeTallImage()
    let image = frame(of: tall, offset: 700)

    let stitcher = ScrollStitcher()
    #expect(stitcher.findOffset(previous: image, next: image) == 0)

    let stitched = try stitcher.stitch(frames: [image, image])
    #expect(stitched.frameCount == 1)
    #expect(stitched.image.height == frameHeight)
    #expect(pixels(of: stitched.image) == pixels(of: image))
}

@Test func reversedScrollIsRejectedWithoutCorruption() {
    let tall = makeTallImage()
    // next 反而往回滚：内容相对 previous 向下移动，不是长截图的方向。
    let previous = frame(of: tall, offset: 1200)
    let next = frame(of: tall, offset: 800)

    let stitcher = ScrollStitcher()
    let offset = stitcher.findOffset(previous: previous, next: next)
    #expect(offset == nil || offset == 0)

    do {
        let stitched = try stitcher.stitch(frames: [previous, next])
        // 首对偏移为 0 时会退化成单帧结果，绝不能拼出重复或错位的内容。
        #expect(stitched.frameCount == 1)
        #expect(pixels(of: stitched.image) == pixels(of: previous))
    } catch let error as ScrollStitchError {
        #expect(error == ScrollStitchError.noOverlap)
    } catch {
        Issue.record("unexpected error: \(error)")
    }
}

@Test func unrelatedFramesReportNoOverlap() {
    let first = makeRandomImage(width: tallWidth, height: frameHeight, seed: 1)
    let second = makeRandomImage(width: tallWidth, height: frameHeight, seed: 2)

    let stitcher = ScrollStitcher()
    #expect(stitcher.findOffset(previous: first, next: second) == nil)
    #expect(throws: ScrollStitchError.noOverlap) {
        _ = try stitcher.stitch(frames: [first, second])
    }
}

@Test func emptyFramesThrow() {
    #expect(throws: ScrollStitchError.emptyFrames) {
        _ = try ScrollStitcher().stitch(frames: [])
    }
}

@Test func mismatchedFrameSizesFail() {
    let tall = makeTallImage()
    let first = frame(of: tall, offset: 0)
    let second = frame(of: tall, offset: 400, height: frameHeight - 100)

    #expect(throws: ScrollStitchError.decodeFailed) {
        _ = try ScrollStitcher().stitch(frames: [first, second])
    }
}

@Test func singleFrameIsReturnedAsIs() throws {
    let tall = makeTallImage()
    let only = frame(of: tall, offset: 400)

    let stitched = try ScrollStitcher().stitch(frames: [only])
    #expect(stitched.frameCount == 1)
    #expect(stitched.image.width == only.width)
    #expect(stitched.image.height == only.height)
    #expect(pixels(of: stitched.image) == pixels(of: only))
}

@Test func unmatchedTailStopsStitchingButKeepsContent() throws {
    let tall = makeTallImage()
    let first = frame(of: tall, offset: 0)
    let second = frame(of: tall, offset: scrollStep)
    let unrelated = makeRandomImage(width: tallWidth, height: frameHeight, seed: 99)

    let stitched = try ScrollStitcher().stitch(frames: [first, second, unrelated])

    // 最后一对没有重叠：只返回前两帧拼好的内容，不抛错、不丢内容。
    #expect(stitched.frameCount == 2)
    let expectedHeight = frameHeight + scrollStep
    #expect(stitched.image.height == expectedHeight)
    let bytesPerRow = tallWidth * 4
    #expect(pixels(of: stitched.image) == Array(pixels(of: tall)[0..<(expectedHeight * bytesPerRow)]))
}

@Test func maximumSearchDistanceLimitsOffsetDetection() {
    let tall = makeTallImage()
    let previous = frame(of: tall, offset: 0)
    let next = frame(of: tall, offset: scrollStep)

    var stitcher = ScrollStitcher()
    stitcher.maximumSearchDistance = 100
    #expect(stitcher.findOffset(previous: previous, next: next) == nil)
}

@Test func minimumOverlapIsRespected() {
    let tall = makeTallImage()
    let previous = frame(of: tall, offset: 0)
    let next = frame(of: tall, offset: scrollStep)

    var stitcher = ScrollStitcher()
    // 重叠只剩 200px，低于要求的 250px：必须拒绝，避免可信度不足的拼接。
    stitcher.minimumOverlap = 250
    #expect(stitcher.findOffset(previous: previous, next: next) == nil)
}
