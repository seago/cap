import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Cap

private func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CapFileExporterTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeImage(width: Int = 8, height: Int = 6) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

/// 伪随机噪点图：JPEG 高低质量的文件大小差异明显，适合验证质量参数生效。
private func makeNoiseImage(width: Int = 128, height: Int = 128) -> CGImage {
    let bytesPerRow = width * 4
    var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
    var state: UInt64 = 0x9E37_79B9_7F4A_7C15
    for index in stride(from: 0, to: bytes.count, by: 4) {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        bytes[index] = UInt8(truncatingIfNeeded: state >> 33)
        bytes[index + 1] = UInt8(truncatingIfNeeded: state >> 41)
        bytes[index + 2] = UInt8(truncatingIfNeeded: state >> 49)
        bytes[index + 3] = 255
    }

    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )!
}

private func decodeImage(at url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

@Test func defaultDirectoryIsPicturesScreenshots() {
    let expected = FileManager.default
        .urls(for: .picturesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Screenshots", isDirectory: true)
    #expect(FileExporter.defaultDirectory.standardizedFileURL == expected.standardizedFileURL)
}

@Test func savesPNGIntoInjectedDirectoryAndCreatesIt() throws {
    let root = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    // 目录故意不存在，导出时应自动创建（含中间目录）。
    let directory = root.appendingPathComponent("nested/Screenshots", isDirectory: true)
    let exporter = FileExporter(directory: directory)
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    let url = try exporter.save(makeImage(), at: date)

    var isDirectory: ObjCBool = false
    #expect(FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory))
    #expect(isDirectory.boolValue)
    #expect(url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL)
    #expect(url.pathExtension == "png")
    #expect(url.lastPathComponent == FileNaming.fileName(for: date, fileExtension: "png"))
    #expect(FileManager.default.fileExists(atPath: url.path))

    let decoded = try #require(decodeImage(at: url), "导出的文件应当是合法 PNG")
    #expect(decoded.width == 8)
    #expect(decoded.height == 6)
}

@Test func savingTwiceInSameSecondAppendsSequenceNumber() throws {
    let root = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let exporter = FileExporter(directory: root)
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let baseName = FileNaming.fileName(for: date, fileExtension: "png")

    let first = try exporter.save(makeImage(), at: date)
    let second = try exporter.save(makeImage(width: 4, height: 4), at: date)
    let third = try exporter.save(makeImage(width: 2, height: 2), at: date)

    #expect(first.lastPathComponent == baseName)
    #expect(second.lastPathComponent == baseName.replacingOccurrences(of: ".png", with: " 2.png"))
    #expect(third.lastPathComponent == baseName.replacingOccurrences(of: ".png", with: " 3.png"))
    #expect(Set([first, second, third]).count == 3, "三次保存应落在三个不同文件")
    #expect(try decodeImage(at: second)?.width == 4)
    #expect(try decodeImage(at: third)?.width == 2)
}

@Test func savesJPEGAndQualityAffectsOutput() throws {
    let root = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let image = makeNoiseImage()
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    let lowQualityURL = try FileExporter(directory: root, format: .jpeg, jpegQuality: 0.2)
        .save(image, at: date)
    let highQualityURL = try FileExporter(directory: root, format: .jpeg, jpegQuality: 0.9)
        .save(image, at: date)

    #expect(lowQualityURL.pathExtension == "jpg")
    #expect(highQualityURL.pathExtension == "jpg")
    #expect(lowQualityURL != highQualityURL, "同一秒的第二次保存应追加序号")

    let lowQualityData = try Data(contentsOf: lowQualityURL)
    let highQualityData = try Data(contentsOf: highQualityURL)
    #expect(lowQualityData != highQualityData)
    #expect(lowQualityData.count < highQualityData.count, "低质量 JPEG 应比高质量 JPEG 更小")

    let decoded = try #require(decodeImage(at: lowQualityURL), "导出的文件应当是合法 JPEG")
    #expect(decoded.width == 128)
    #expect(decoded.height == 128)
}

@Test func saveThrowsWhenDirectoryCannotBeCreated() throws {
    let root = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    // 用普通文件占住目录路径，让 createDirectory 失败。
    let blocker = root.appendingPathComponent("blocker")
    try Data("not a directory".utf8).write(to: blocker)

    let exporter = FileExporter(directory: blocker.appendingPathComponent("Screenshots", isDirectory: true))
    #expect(throws: FileExportError.directoryCreationFailed) {
        _ = try exporter.save(makeImage())
    }
}
