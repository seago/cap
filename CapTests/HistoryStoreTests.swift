import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Cap

private func makeTempRoot() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CapHistoryTests-\(UUID().uuidString)", isDirectory: true)
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

private func decodeImage(at url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

private func fileSystemNumber(of url: URL) -> Int? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
          let number = attributes[.systemFileNumber] as? NSNumber else {
        return nil
    }
    return number.intValue
}

@Test func defaultRootIsApplicationSupportCapHistory() {
    let expected = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Cap", isDirectory: true)
        .appendingPathComponent("History", isDirectory: true)
    #expect(HistoryStore.defaultRootURL.standardizedFileURL == expected.standardizedFileURL)
}

@Test func historySourceRoundTripsThroughJSON() throws {
    let sources: [HistorySource] = [
        .region(CGRect(x: 1, y: 2, width: 3, height: 4)),
        .window(42),
        .display(7),
        .unknown,
    ]
    let data = try JSONEncoder().encode(sources)
    #expect(try JSONDecoder().decode([HistorySource].self, from: data) == sources)
}

@Test @MainActor func appendWritesPNGAndIndexThenLoadsRoundTrip() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = HistoryStore(rootURL: root)
    #expect(store.items.isEmpty)

    let capturedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let item = try store.append(makeImage(), source: .display(7), capturedAt: capturedAt)

    #expect(store.items == [item])
    #expect(item.fileName == "\(item.id.uuidString).png")
    #expect(item.pixelWidth == 8)
    #expect(item.pixelHeight == 6)
    #expect(item.source == .display(7))
    #expect(!item.isAnnotated)
    #expect(item.createdAt == capturedAt)
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("index.json").path))

    let imageURL = root.appendingPathComponent("images").appendingPathComponent(item.fileName)
    #expect(FileManager.default.fileExists(atPath: imageURL.path))
    let decoded = try #require(decodeImage(at: imageURL), "历史图片应当是合法 PNG")
    #expect(decoded.width == item.pixelWidth)
    #expect(decoded.height == item.pixelHeight)

    // 重新创建 store 模拟重启 App：从 index.json 读回同一条。
    let reloaded = HistoryStore(rootURL: root)
    #expect(reloaded.items == [item])
}

@Test @MainActor func appendsAreNewestFirst() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = HistoryStore(rootURL: root)
    let older = try store.append(makeImage(width: 2, height: 2), source: .display(1), capturedAt: Date(timeIntervalSince1970: 1_000))
    let newer = try store.append(makeImage(width: 3, height: 3), source: .display(1), capturedAt: Date(timeIntervalSince1970: 2_000))

    #expect(store.items.map(\.id) == [newer.id, older.id])
    let reloaded = HistoryStore(rootURL: root)
    #expect(reloaded.items.map(\.id) == [newer.id, older.id])
}

@Test @MainActor func indexIsRewrittenAtomically() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = HistoryStore(rootURL: root)
    _ = try store.append(makeImage(), source: .display(1), capturedAt: Date(timeIntervalSince1970: 1_000))

    let indexURL = root.appendingPathComponent("index.json")
    let firstFileNumber = try #require(fileSystemNumber(of: indexURL))

    _ = try store.append(makeImage(width: 4, height: 4), source: .display(1), capturedAt: Date(timeIntervalSince1970: 2_000))
    let secondFileNumber = try #require(fileSystemNumber(of: indexURL))

    // 临时文件 + rename 会替换目录项，而不是原地截断重写，因此 inode 变化。
    #expect(firstFileNumber != secondFileNumber)
    #expect(!FileManager.default.fileExists(atPath: indexURL.appendingPathExtension("tmp").path), "原子写不应遗留临时文件")
    #expect(HistoryStore(rootURL: root).items.count == 2)
}

@Test @MainActor func corruptIndexIsRebuiltFromImages() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = HistoryStore(rootURL: root)
    let indexed = try store.append(makeImage(width: 8, height: 6), source: .display(2), capturedAt: Date(timeIntervalSince1970: 1_000))

    try Data("{ this is not json".utf8).write(to: root.appendingPathComponent("index.json"))

    // 一张只存在于 images/ 的孤儿 PNG，重建时应被收进索引。
    let orphanID = UUID()
    let orphanURL = root.appendingPathComponent("images").appendingPathComponent("\(orphanID.uuidString).png")
    let orphanPNG = try #require(ImageEncoder.pngData(from: makeImage(width: 4, height: 2)))
    try orphanPNG.write(to: orphanURL)

    let rebuilt = HistoryStore(rootURL: root)
    #expect(rebuilt.items.count == 2)
    #expect(Set(rebuilt.items.map(\.id)) == Set([indexed.id, orphanID]))

    let rebuiltIndexed = try #require(rebuilt.items.first { $0.id == indexed.id })
    #expect(rebuiltIndexed.source == .unknown)
    #expect(rebuiltIndexed.pixelWidth == 8)
    #expect(rebuiltIndexed.pixelHeight == 6)
    #expect(!rebuiltIndexed.isAnnotated)
    #expect(rebuiltIndexed.fileName == indexed.fileName)

    let rebuiltOrphan = try #require(rebuilt.items.first { $0.id == orphanID })
    #expect(rebuiltOrphan.source == .unknown)
    #expect(rebuiltOrphan.pixelWidth == 4)
    #expect(rebuiltOrphan.pixelHeight == 2)

    // 重建后的 index.json 恢复合法，并能再次加载。
    let reloaded = HistoryStore(rootURL: root)
    #expect(reloaded.items == rebuilt.items)
}

@Test @MainActor func createsDirectoriesOnFirstInit() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = HistoryStore(rootURL: root)
    #expect(store.items.isEmpty)

    for directory in [store.imagesURL, store.thumbsURL] {
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
    }
    #expect(HistoryStore.defaultHistoryLimit == 100)
}

@Test @MainActor func replaceWithAnnotatedOverwritesImageAndMarksAnnotated() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = HistoryStore(rootURL: root)
    let original = try store.append(
        makeImage(width: 8, height: 6),
        source: .display(3),
        capturedAt: Date(timeIntervalSince1970: 1_000)
    )
    let imageURL = store.imagesURL.appendingPathComponent(original.fileName)
    let originalFileNumber = try #require(fileSystemNumber(of: imageURL))

    let annotated = try store.replaceWithAnnotated(id: original.id, image: makeImage(width: 5, height: 4))

    // 同一条记录、同一个文件名，尺寸与标注状态更新。
    #expect(annotated.id == original.id)
    #expect(annotated.fileName == original.fileName)
    #expect(annotated.createdAt == original.createdAt)
    #expect(annotated.source == .display(3))
    #expect(annotated.isAnnotated)
    #expect(annotated.pixelWidth == 5)
    #expect(annotated.pixelHeight == 4)
    #expect(store.items == [annotated])

    // 原文件被标注版覆盖（原子写替换目录项，inode 变化）。
    #expect(FileManager.default.fileExists(atPath: imageURL.path))
    let annotatedFileNumber = try #require(fileSystemNumber(of: imageURL))
    #expect(originalFileNumber != annotatedFileNumber)
    let decoded = try #require(decodeImage(at: imageURL), "历史图片应当是合法 PNG")
    #expect(decoded.width == 5)
    #expect(decoded.height == 4)

    // 重启 App 后仍是标注版。
    let reloaded = HistoryStore(rootURL: root)
    #expect(reloaded.items == [annotated])
}

@Test @MainActor func replaceWithAnnotatedPreservesOtherItemsAndOrder() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = HistoryStore(rootURL: root)
    let older = try store.append(
        makeImage(width: 2, height: 2),
        source: .region(CGRect(x: 1, y: 2, width: 3, height: 4)),
        capturedAt: Date(timeIntervalSince1970: 1_000)
    )
    let newer = try store.append(
        makeImage(width: 3, height: 3),
        source: .display(1),
        capturedAt: Date(timeIntervalSince1970: 2_000)
    )

    _ = try store.replaceWithAnnotated(id: older.id, image: makeImage(width: 9, height: 7))

    #expect(store.items.map(\.id) == [newer.id, older.id], "替换不应改变历史顺序")
    #expect(!store.items[0].isAnnotated)
    #expect(store.items[1].isAnnotated)
    #expect(store.items[1].pixelWidth == 9)
    #expect(store.items[1].pixelHeight == 7)
    #expect(store.items[1].source == .region(CGRect(x: 1, y: 2, width: 3, height: 4)))

    let reloaded = HistoryStore(rootURL: root)
    #expect(reloaded.items.map(\.id) == [newer.id, older.id])
    #expect(!reloaded.items[0].isAnnotated)
    #expect(reloaded.items[1].isAnnotated)
    #expect(reloaded.items[1].pixelWidth == 9)
    #expect(reloaded.items[1].pixelHeight == 7)
}

@Test @MainActor func replaceWithAnnotatedRewritesIndexAtomically() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = HistoryStore(rootURL: root)
    let item = try store.append(makeImage(), source: .display(1), capturedAt: Date(timeIntervalSince1970: 1_000))

    let indexURL = root.appendingPathComponent("index.json")
    let beforeFileNumber = try #require(fileSystemNumber(of: indexURL))

    _ = try store.replaceWithAnnotated(id: item.id, image: makeImage(width: 4, height: 4))

    let afterFileNumber = try #require(fileSystemNumber(of: indexURL))
    #expect(beforeFileNumber != afterFileNumber)
    #expect(!FileManager.default.fileExists(atPath: indexURL.appendingPathExtension("tmp").path), "原子写不应遗留临时文件")
    #expect(HistoryStore(rootURL: root).items.first?.isAnnotated == true)
}

@Test @MainActor func replaceWithAnnotatedUnknownIDThrowsAndDoesNotLeakFiles() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = HistoryStore(rootURL: root)
    let existing = try store.append(makeImage(), source: .display(1), capturedAt: Date(timeIntervalSince1970: 1_000))
    let imagesBefore = try FileManager.default.contentsOfDirectory(at: store.imagesURL, includingPropertiesForKeys: nil)

    #expect(throws: HistoryError.itemNotFound) {
        _ = try store.replaceWithAnnotated(id: UUID(), image: makeImage(width: 3, height: 3))
    }

    #expect(store.items.count == 1)
    #expect(store.items.first == existing)
    #expect(!store.items[0].isAnnotated)
    let imagesAfter = try FileManager.default.contentsOfDirectory(at: store.imagesURL, includingPropertiesForKeys: nil)
    #expect(imagesAfter.count == imagesBefore.count)
}

// MARK: - #23 删除单条 / 清空历史

@Test @MainActor func deleteRemovesIndexEntryImageAndThumbnail() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = HistoryStore(rootURL: root)
    let older = try store.append(
        makeImage(width: 8, height: 6),
        source: .display(1),
        capturedAt: Date(timeIntervalSince1970: 1_000)
    )
    let newer = try store.append(
        makeImage(width: 9, height: 7),
        source: .display(1),
        capturedAt: Date(timeIntervalSince1970: 2_000)
    )
    let olderThumbFileName = try #require(older.thumbFileName)
    let olderThumbURL = store.thumbsURL.appendingPathComponent(olderThumbFileName)
    #expect(FileManager.default.fileExists(atPath: olderThumbURL.path))

    try store.delete(id: older.id)

    #expect(store.items == [newer])
    #expect(!FileManager.default.fileExists(atPath: store.imageURL(for: older).path), "删除记录应删掉图片文件")
    #expect(!FileManager.default.fileExists(atPath: olderThumbURL.path), "删除记录应删掉缩略图文件")
    #expect(FileManager.default.fileExists(atPath: store.imageURL(for: newer).path), "不应误删其他记录")

    // 索引已更新：重启后只剩 newer，且磁盘无残留。
    let reloaded = HistoryStore(rootURL: root)
    #expect(reloaded.items == [newer])
    let imageFiles = try FileManager.default.contentsOfDirectory(at: store.imagesURL, includingPropertiesForKeys: nil)
    let thumbFiles = try FileManager.default.contentsOfDirectory(at: store.thumbsURL, includingPropertiesForKeys: nil)
    #expect(imageFiles.count == 1)
    #expect(thumbFiles.count == 1)
}

@Test @MainActor func deleteUnknownIDThrowsAndChangesNothing() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = HistoryStore(rootURL: root)
    let existing = try store.append(makeImage(), source: .display(1))
    let imagesBefore = try FileManager.default.contentsOfDirectory(at: store.imagesURL, includingPropertiesForKeys: nil)
    let thumbsBefore = try FileManager.default.contentsOfDirectory(at: store.thumbsURL, includingPropertiesForKeys: nil)

    #expect(throws: HistoryError.itemNotFound) {
        try store.delete(id: UUID())
    }

    #expect(store.items == [existing])
    let imagesAfter = try FileManager.default.contentsOfDirectory(at: store.imagesURL, includingPropertiesForKeys: nil)
    let thumbsAfter = try FileManager.default.contentsOfDirectory(at: store.thumbsURL, includingPropertiesForKeys: nil)
    #expect(imagesAfter.count == imagesBefore.count)
    #expect(thumbsAfter.count == thumbsBefore.count)
}

@Test @MainActor func clearAllEmptiesIndexAndDirectories() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = HistoryStore(rootURL: root)
    _ = try store.append(makeImage(width: 2, height: 2), source: .display(1), capturedAt: Date(timeIntervalSince1970: 1_000))
    _ = try store.append(makeImage(width: 3, height: 3), source: .display(1), capturedAt: Date(timeIntervalSince1970: 2_000))
    _ = try store.append(makeImage(width: 4, height: 4), source: .display(1), capturedAt: Date(timeIntervalSince1970: 3_000))

    // 一张只存在于 images/ 的孤儿文件，清空历史时一并清掉。
    let orphanURL = store.imagesURL.appendingPathComponent("\(UUID().uuidString).png")
    let orphanPNG = try #require(ImageEncoder.pngData(from: makeImage(width: 4, height: 2)))
    try orphanPNG.write(to: orphanURL)

    try store.clearAll()

    #expect(store.items.isEmpty)
    #expect(store.recentItems(limit: 8).isEmpty)
    #expect(try FileManager.default.contentsOfDirectory(at: store.imagesURL, includingPropertiesForKeys: nil).isEmpty)
    #expect(try FileManager.default.contentsOfDirectory(at: store.thumbsURL, includingPropertiesForKeys: nil).isEmpty)

    // 索引已清空：重启后仍为空。
    let reloaded = HistoryStore(rootURL: root)
    #expect(reloaded.items.isEmpty)
}

// MARK: - #22 popover 用的读取接口

@Test @MainActor func recentItemsReturnsNewestFirstAndRespectsLimit() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = HistoryStore(rootURL: root)
    #expect(store.recentItems(limit: 8).isEmpty, "空历史返回空数组")

    let first = try store.append(makeImage(width: 2, height: 2), source: .display(1), capturedAt: Date(timeIntervalSince1970: 1_000))
    let second = try store.append(makeImage(width: 3, height: 3), source: .display(1), capturedAt: Date(timeIntervalSince1970: 2_000))
    let third = try store.append(makeImage(width: 4, height: 4), source: .display(1), capturedAt: Date(timeIntervalSince1970: 3_000))

    #expect(store.recentItems(limit: 2).map(\.id) == [third.id, second.id])
    #expect(store.recentItems(limit: 8).map(\.id) == [third.id, second.id, first.id])
    #expect(store.recentItems(limit: 0).isEmpty)
    #expect(store.recentItems(limit: -1).isEmpty)
}

@Test @MainActor func imageDataReturnsOriginalPNGBytes() throws {
    let root = makeTempRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = HistoryStore(rootURL: root)
    let item = try store.append(makeImage(width: 8, height: 6), source: .display(1))

    let data = try #require(store.imageData(for: item))
    #expect(Array(data.prefix(8)) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], "imageData 应是 PNG 原始字节")
    #expect(data == (try Data(contentsOf: store.imageURL(for: item))))

    let decoded = try #require(decodeImage(at: store.imageURL(for: item)))
    #expect(decoded.width == 8)
    #expect(decoded.height == 6)
    #expect(store.loadImage(for: item)?.width == 8)

    // 标注版替换后，imageData 返回标注后的 PNG 字节（popover 复制用）。
    let annotated = try store.replaceWithAnnotated(id: item.id, image: makeImage(width: 5, height: 4))
    let annotatedData = try #require(store.imageData(for: annotated))
    #expect(annotatedData != data)
    #expect(try #require(decodeImage(at: store.imageURL(for: annotated))).width == 5)
}
