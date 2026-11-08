import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Cap

private func makeTempRoot() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CapHistoryRetentionTests-\(UUID().uuidString)", isDirectory: true)
}

private func makeImage(width: Int = 40, height: Int = 24) -> CGImage {
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

private func decodeImage(at url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

private func decodeImageData(_ data: Data) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

private func fileURLs(in directory: URL) -> [URL] {
    (try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    )) ?? []
}

/// #24 验收：插入 105 条后剩 100 条，最旧的 5 条图片与缩略图被删除，索引与磁盘一致。
@Test @MainActor func insertingBeyondLimitKeepsNewestHundredAndDeletesFiles() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = HistoryStore(rootURL: root)

    var appended: [HistoryItem] = []
    for index in 0..<105 {
        let item = try store.append(
            makeImage(),
            source: .display(1),
            capturedAt: Date(timeIntervalSince1970: Double(index))
        )
        appended.append(item)
    }

    #expect(store.items.count == 100)
    // 索引新到旧：最后插入的在最前。
    #expect(store.items.map(\.id) == appended.suffix(100).reversed().map(\.id))

    let pruned = appended.prefix(5)
    for item in pruned {
        #expect(!FileManager.default.fileExists(atPath: store.imageURL(for: item).path))
        let thumbFileName = try #require(item.thumbFileName)
        let thumbURL = store.thumbsURL.appendingPathComponent(thumbFileName)
        #expect(!FileManager.default.fileExists(atPath: thumbURL.path))
        #expect(!store.items.contains { $0.id == item.id })
    }

    // 磁盘上的图片/缩略图与索引一一对应。
    #expect(fileURLs(in: store.imagesURL).count == 100)
    #expect(fileURLs(in: store.thumbsURL).count == 100)

    // 重启后索引一致：仍是同样的 100 条、同样的顺序。
    let reloaded = HistoryStore(rootURL: root)
    #expect(reloaded.items.map(\.id) == store.items.map(\.id))
    #expect(reloaded.items.count == 100)
}

@Test @MainActor func appendWritesThumbnailAt320Pixels() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = HistoryStore(rootURL: root)

    let item = try store.append(makeImage(width: 640, height: 360), source: .region(CGRect(x: 1, y: 2, width: 3, height: 4)))
    let thumbFileName = try #require(item.thumbFileName, "新记录应当有缩略图")
    #expect(thumbFileName == "\(item.id.uuidString).jpg")

    let thumbURL = try #require(store.thumbnailURL(for: item))
    #expect(thumbURL == store.thumbsURL.appendingPathComponent(thumbFileName))
    #expect(FileManager.default.fileExists(atPath: thumbURL.path))

    let thumbnail = try #require(decodeImage(at: thumbURL), "缩略图应当是合法 JPEG")
    #expect(thumbnail.width == 320)
    #expect(thumbnail.height == 180)

    #expect(store.thumbnailData(for: item) != nil)
    #expect(store.loadThumbnail(for: item)?.width == 320)
}

@Test @MainActor func legacyIndexWithoutThumbFileNameLoadsAndBackfillsThumbnails() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    // 手工构造 #24 之前格式的 index.json：没有 thumbFileName 字段。
    try FileManager.default.createDirectory(
        at: root.appendingPathComponent("images"),
        withIntermediateDirectories: true
    )
    let id = UUID()
    let imageFileName = "\(id.uuidString).png"
    let png = try #require(ImageEncoder.pngData(from: makeImage(width: 640, height: 360)))
    try png.write(to: root.appendingPathComponent("images").appendingPathComponent(imageFileName))

    struct LegacyHistoryItem: Codable {
        let id: UUID
        let createdAt: Date
        let source: HistorySource
        let pixelWidth: Int
        let pixelHeight: Int
        let fileName: String
        let isAnnotated: Bool
    }
    let legacy = LegacyHistoryItem(
        id: id,
        createdAt: Date(timeIntervalSince1970: 1_000),
        source: .display(2),
        pixelWidth: 640,
        pixelHeight: 360,
        fileName: imageFileName,
        isAnnotated: false
    )
    let indexData = try JSONEncoder().encode([legacy])
    try indexData.write(to: root.appendingPathComponent("index.json"))

    // 向后兼容：老索引能解码，thumbFileName 为 nil。
    let decoded = try JSONDecoder().decode([HistoryItem].self, from: indexData)
    #expect(decoded.count == 1)
    #expect(decoded[0].thumbFileName == nil)

    // 加载时补生成缩略图并回写索引。
    let store = HistoryStore(rootURL: root)
    #expect(store.items.count == 1)
    let item = try #require(store.items.first)
    #expect(item.id == id)
    #expect(item.thumbFileName == "\(id.uuidString).jpg")
    let thumbURL = try #require(store.thumbnailURL(for: item))
    #expect(decodeImage(at: thumbURL)?.width == 320)

    // 回写后的索引可再次加载，且不再触发补生成。
    let reloaded = HistoryStore(rootURL: root)
    #expect(reloaded.items == [item])
}

@Test @MainActor func replaceWithAnnotatedRegeneratesThumbnail() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = HistoryStore(rootURL: root)

    let item = try store.append(makeImage(width: 640, height: 360), source: .display(1))
    let thumbURL = try #require(store.thumbnailURL(for: item))
    #expect(decodeImage(at: thumbURL)?.width == 320)

    let annotated = try store.replaceWithAnnotated(id: item.id, image: makeImage(width: 200, height: 100))
    #expect(annotated.isAnnotated)
    let annotatedThumbURL = try #require(store.thumbnailURL(for: annotated))
    let thumbnail = try #require(decodeImage(at: annotatedThumbURL))
    #expect(thumbnail.width == 200)
    #expect(thumbnail.height == 100)
}

@Test @MainActor func customHistoryLimitIsRespected() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = HistoryStore(rootURL: root, historyLimit: 3)

    var appended: [HistoryItem] = []
    for index in 0..<5 {
        appended.append(try store.append(makeImage(), source: .display(1), capturedAt: Date(timeIntervalSince1970: Double(index))))
    }

    #expect(store.items.count == 3)
    #expect(store.items.map(\.id) == appended.suffix(3).reversed().map(\.id))
    #expect(fileURLs(in: store.imagesURL).count == 3)
    #expect(fileURLs(in: store.thumbsURL).count == 3)
}

@Test @MainActor func appendFailureRollsBackWithoutLeakingFiles() throws {
    let root = makeTempRoot()
    defer {
        // 恢复权限，保证临时目录可以被删除。
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
        try? FileManager.default.removeItem(at: root)
    }
    let store = HistoryStore(rootURL: root)

    _ = try store.append(makeImage(), source: .display(1), capturedAt: Date(timeIntervalSince1970: 1_000))
    let imagesBefore = fileURLs(in: store.imagesURL).count
    let thumbsBefore = fileURLs(in: store.thumbsURL).count

    // 根目录只读（图片/缩略图子目录仍可写），让索引临时文件的写入失败。
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: root.path)

    #expect(throws: HistoryError.indexWriteFailed) {
        _ = try store.append(makeImage(), source: .display(1), capturedAt: Date(timeIntervalSince1970: 2_000))
    }

    #expect(store.items.count == 1)
    let indexURL = root.appendingPathComponent("index.json")
    #expect(!FileManager.default.fileExists(atPath: indexURL.appendingPathExtension("tmp").path), "原子写不应遗留临时文件")
    // 回滚后不应泄漏新写入的图片/缩略图。
    #expect(fileURLs(in: store.imagesURL).count == imagesBefore)
    #expect(fileURLs(in: store.thumbsURL).count == thumbsBefore)
}
