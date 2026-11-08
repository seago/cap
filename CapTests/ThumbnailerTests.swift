import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Cap

private func makeTestImage(
    width: Int,
    height: Int,
    red: CGFloat = 0.2,
    green: CGFloat = 0.4,
    blue: CGFloat = 0.8
) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

private func decode(_ data: Data) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

private func imageTypeIdentifier(of data: Data) -> String? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let type = CGImageSourceGetType(source) else {
        return nil
    }
    return type as String
}

@Test func landscapeImageScalesTo320WideKeepingAspectRatio() throws {
    let data = try #require(Thumbnailer.jpegData(from: makeTestImage(width: 640, height: 360)))
    let image = try #require(decode(data), "缩略图应当是合法图片")
    #expect(image.width == 320)
    #expect(image.height == 180)
    #expect(imageTypeIdentifier(of: data) == "public.jpeg")
}

@Test func portraitImageScalesByWidthKeepingAspectRatio() throws {
    let data = try #require(Thumbnailer.jpegData(from: makeTestImage(width: 900, height: 1200)))
    let image = try #require(decode(data))
    #expect(image.width == 320)
    // 1200 * 320 / 900 = 426.67 -> 427
    #expect(image.height == 427)
}

@Test func oddAspectRatioRoundsAspectCorrectly() throws {
    let data = try #require(Thumbnailer.jpegData(from: makeTestImage(width: 1000, height: 333)))
    let image = try #require(decode(data))
    #expect(image.width == 320)
    // 333 * 320 / 1000 = 106.56 -> 107
    #expect(image.height == 107)
}

@Test func squareImageScalesTo320Square() throws {
    let data = try #require(Thumbnailer.jpegData(from: makeTestImage(width: 1024, height: 1024)))
    let image = try #require(decode(data))
    #expect(image.width == 320)
    #expect(image.height == 320)
}

@Test func smallImageIsNotUpscaled() throws {
    let data = try #require(Thumbnailer.jpegData(from: makeTestImage(width: 100, height: 50)))
    let image = try #require(decode(data))
    #expect(image.width == 100)
    #expect(image.height == 50)
}

@Test func thumbnailIsEightBitRGBJPEG() throws {
    let data = try #require(Thumbnailer.jpegData(from: makeTestImage(width: 640, height: 360)))
    #expect(imageTypeIdentifier(of: data) == "public.jpeg")
    let image = try #require(decode(data))
    #expect(image.bitsPerComponent == 8)
    #expect(image.colorSpace?.model == .rgb)
    #expect(image.alphaInfo == .none || image.alphaInfo == .noneSkipLast || image.alphaInfo == .noneSkipFirst)
}

@Test func scaledSizeHandlesDegenerateSizes() {
    #expect(Thumbnailer.scaledSize(width: 0, height: 240) == Thumbnailer.PixelSize(width: 0, height: 0))
    #expect(Thumbnailer.scaledSize(width: 640, height: 0) == Thumbnailer.PixelSize(width: 0, height: 0))
    #expect(Thumbnailer.scaledSize(width: 320, height: 200) == Thumbnailer.PixelSize(width: 320, height: 200))
    #expect(Thumbnailer.scaledSize(width: 100_000, height: 1_000) == Thumbnailer.PixelSize(width: 320, height: 3))
}

@Test func jpegDataForInvalidTargetWidthReturnsNil() {
    #expect(Thumbnailer.jpegData(from: makeTestImage(width: 100, height: 100), maxPixelWidth: 0) == nil)
}
