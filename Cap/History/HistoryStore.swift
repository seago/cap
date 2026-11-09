import CoreGraphics
import Foundation
import ImageIO

extension Notification.Name {
    /// 历史内容发生变化（append / replace / delete / clearAll / 索引重建）后发送。
    /// UI（历史窗口、popover）监听后刷新自己的数据展示。
    static let historyStoreDidChange = Notification.Name("CapHistoryStoreDidChange")
}

enum HistoryError: LocalizedError, Equatable {
    case encodingFailed
    case imageWriteFailed
    case indexWriteFailed
    case itemNotFound

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return String(localized: "无法把截图编码为 PNG。")
        case .imageWriteFailed:
            return String(localized: "无法写入历史图片文件。")
        case .indexWriteFailed:
            return String(localized: "无法写入历史索引。")
        case .itemNotFound:
            return String(localized: "找不到这条历史记录。")
        }
    }
}

/// 截图历史的本地存储，目录布局见 `DESIGN.md` §6.1：
///
/// ```
/// History/
/// ├─ index.json          // [HistoryItem]，新到旧
/// ├─ images/{uuid}.png   // 原图或标注版
/// └─ thumbs/{uuid}.jpg   // 320px 缩略图
/// ```
///
/// 索引原子写（临时文件 + rename）；启动时加载，索引损坏或缺失则扫描 `images/` 重建。
/// 超过 `historyLimit`（默认 100，`DESIGN.md` §6.2）时删最旧记录，连同图片与缩略图。
/// 缩略图生成失败不阻断截图入库，该条记录的 `thumbFileName` 为 `nil`。
@MainActor
final class HistoryStore {
    private enum Constants {
        static let imagesDirectoryName = "images"
        static let thumbnailsDirectoryName = "thumbs"
        static let indexFileName = "index.json"
        static let indexTempFileExtension = "tmp"
        static let imageFileExtension = "png"
        static let thumbnailFileExtension = "jpg"
    }

    /// 默认历史上限，`DESIGN.md` §6.2：100（v1 不暴露修改）。
    nonisolated static let defaultHistoryLimit = 100

    /// `~/Library/Application Support/Cap/History/`
    nonisolated static var defaultRootURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cap", isDirectory: true)
            .appendingPathComponent("History", isDirectory: true)
    }

    private let fileManager: FileManager
    let rootURL: URL
    let imagesURL: URL
    /// 缩略图目录 `History/thumbs/`。
    let thumbsURL: URL
    let indexURL: URL
    /// 保留的最大记录数；超过后删最旧。
    let historyLimit: Int

    /// 已加载的记录，新到旧。
    private(set) var items: [HistoryItem] = []

    init(
        rootURL: URL,
        fileManager: FileManager = .default,
        historyLimit: Int = HistoryStore.defaultHistoryLimit
    ) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        self.imagesURL = rootURL.appendingPathComponent(Constants.imagesDirectoryName, isDirectory: true)
        self.thumbsURL = rootURL.appendingPathComponent(Constants.thumbnailsDirectoryName, isDirectory: true)
        self.indexURL = rootURL.appendingPathComponent(Constants.indexFileName)
        self.historyLimit = max(1, historyLimit)
        createDirectoriesIfNeeded()
        load()
    }

    convenience init() {
        self.init(rootURL: Self.defaultRootURL)
    }

    // MARK: - 写入

    /// 把原图写为 `images/{uuid}.png`、缩略图写为 `thumbs/{uuid}.jpg`，
    /// 并在索引最前面插入一条记录；超过 `historyLimit` 时删除最旧记录及其文件。
    @discardableResult
    func append(_ image: CGImage, source: HistorySource, capturedAt: Date = Date()) throws -> HistoryItem {
        guard let pngData = ImageEncoder.pngData(from: image) else {
            throw HistoryError.encodingFailed
        }

        let id = UUID()
        let fileName = "\(id.uuidString).\(Constants.imageFileExtension)"
        let imageURL = imagesURL.appendingPathComponent(fileName)
        do {
            try pngData.write(to: imageURL, options: .atomic)
        } catch {
            Log.history.error("Failed to write history image \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw HistoryError.imageWriteFailed
        }

        let thumbFileName = writeThumbnail(for: image, id: id)
        let item = HistoryItem(
            id: id,
            createdAt: capturedAt,
            source: source,
            pixelWidth: image.width,
            pixelHeight: image.height,
            fileName: fileName,
            isAnnotated: false,
            thumbFileName: thumbFileName
        )

        let previousItems = items
        items.insert(item, at: 0)
        let overflow = Array(items.dropFirst(historyLimit))
        if !overflow.isEmpty {
            items.removeLast(overflow.count)
        }

        do {
            try writeIndex()
        } catch {
            // 索引写失败时回滚内存与刚写入的文件，保持与磁盘一致。
            items = previousItems
            try? fileManager.removeItem(at: imageURL)
            if let thumbFileName {
                try? fileManager.removeItem(at: thumbsURL.appendingPathComponent(thumbFileName))
            }
            throw error
        }

        // 索引已落盘，再清理被剪枝的旧文件；失败只记日志，不影响本次截图。
        removeFiles(for: overflow)
        postDidChange()
        return item
    }

    /// 用标注版替换 `id` 对应的原图：覆盖 `images/{uuid}.png`，把索引中的该条置 `isAnnotated = true`，
    /// 并重新生成缩略图。
    ///
    /// 索引原子重写；图片或索引写入失败时回滚内存与磁盘，保持两者一致。缩略图失败只记日志。
    @discardableResult
    func replaceWithAnnotated(id: UUID, image: CGImage) throws -> HistoryItem {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw HistoryError.itemNotFound
        }
        guard let pngData = ImageEncoder.pngData(from: image) else {
            throw HistoryError.encodingFailed
        }

        let originalItem = items[index]
        let imageURL = imagesURL.appendingPathComponent(originalItem.fileName)
        let originalData = try? Data(contentsOf: imageURL)

        do {
            try pngData.write(to: imageURL, options: .atomic)
        } catch {
            Log.history.error("Failed to overwrite history image \(originalItem.fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw HistoryError.imageWriteFailed
        }

        // 缩略图跟随标注版重新生成；失败时保留旧缩略图，不让复制/保存标注版失败。
        let originalThumbData: Data? = originalItem.thumbFileName.flatMap { fileName in
            try? Data(contentsOf: thumbsURL.appendingPathComponent(fileName))
        }
        let thumbFileName = writeThumbnail(for: image, id: originalItem.id) ?? originalItem.thumbFileName
        let annotatedItem = HistoryItem(
            id: originalItem.id,
            createdAt: originalItem.createdAt,
            source: originalItem.source,
            pixelWidth: image.width,
            pixelHeight: image.height,
            fileName: originalItem.fileName,
            isAnnotated: true,
            thumbFileName: thumbFileName
        )
        items[index] = annotatedItem
        do {
            try writeIndex()
        } catch {
            // 索引写失败时回滚内存、图片与缩略图，保持与磁盘一致。
            items[index] = originalItem
            if let originalData {
                try? originalData.write(to: imageURL, options: .atomic)
            } else {
                try? fileManager.removeItem(at: imageURL)
            }
            if let originalThumbFileName = originalItem.thumbFileName {
                if let originalThumbData {
                    try? originalThumbData.write(to: thumbsURL.appendingPathComponent(originalThumbFileName), options: .atomic)
                }
            } else if let newThumb = thumbFileName {
                // 原来没有缩略图：删掉这次生成的，避免孤儿文件。
                try? fileManager.removeItem(at: thumbsURL.appendingPathComponent(newThumb))
            }
            throw error
        }
        postDidChange()
        return annotatedItem
    }

    /// 保存某条记录的 OCR 文本（#29）。只改索引，不动图片文件。
    @discardableResult
    func setOCRText(id: UUID, text: String) throws -> HistoryItem {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw HistoryError.itemNotFound
        }
        let original = items[index]
        let updated = HistoryItem(
            id: original.id,
            createdAt: original.createdAt,
            source: original.source,
            pixelWidth: original.pixelWidth,
            pixelHeight: original.pixelHeight,
            fileName: original.fileName,
            isAnnotated: original.isAnnotated,
            thumbFileName: original.thumbFileName,
            ocrText: text
        )
        items[index] = updated
        do {
            try writeIndex()
        } catch {
            items[index] = original
            throw error
        }
        postDidChange()
        return updated
    }

    /// 删除一条记录：先原子重写索引，再删除对应图片与缩略图。
    func delete(id: UUID) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw HistoryError.itemNotFound
        }
        let removed = items.remove(at: index)
        do {
            try writeIndex()
        } catch {
            items.insert(removed, at: index)
            throw error
        }
        removeFiles(for: [removed])
        postDidChange()
    }

    /// 清空全部历史：索引置空，并删除 `images/` 与 `thumbs/` 下的所有文件（含未登记进索引的孤儿文件）。
    func clearAll() throws {
        let previousItems = items
        items = []
        do {
            try writeIndex()
        } catch {
            items = previousItems
            throw error
        }
        for directory in [imagesURL, thumbsURL] {
            removeAllFiles(in: directory)
        }
        postDidChange()
    }

    // MARK: - 读取

    /// 最近 `limit` 条记录，新到旧；空历史或 `limit <= 0` 返回空数组。
    func recentItems(limit: Int) -> [HistoryItem] {
        guard limit > 0 else { return [] }
        return Array(items.prefix(limit))
    }

    /// 原图/标注版文件 URL：`images/{fileName}`。
    func imageURL(for item: HistoryItem) -> URL {
        imagesURL.appendingPathComponent(item.fileName)
    }

    /// 缩略图文件 URL：`thumbs/{thumbFileName}`；无缩略图或文件不存在时为 `nil`。
    func thumbnailURL(for item: HistoryItem) -> URL? {
        guard let thumbFileName = item.thumbFileName else { return nil }
        let url = thumbsURL.appendingPathComponent(thumbFileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    /// 原图/标注版 PNG 数据（`images/{fileName}` 的原始字节，可直接给 `NSImage(data:)`）。
    func imageData(for item: HistoryItem) -> Data? {
        try? Data(contentsOf: imageURL(for: item))
    }

    /// 解码原图/标注版。
    func loadImage(for item: HistoryItem) -> CGImage? {
        Self.decodeImage(at: imageURL(for: item))
    }

    /// 缩略图 JPEG 原始数据。
    func thumbnailData(for item: HistoryItem) -> Data? {
        guard let url = thumbnailURL(for: item) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// 解码缩略图。
    func loadThumbnail(for item: HistoryItem) -> CGImage? {
        guard let url = thumbnailURL(for: item) else { return nil }
        return Self.decodeImage(at: url)
    }

    // MARK: - 缩略图与剪枝

    /// 生成并写入 `thumbs/{uuid}.jpg`，返回缩略图文件名（失败返回 `nil`，不阻断入库）。
    private func writeThumbnail(for image: CGImage, id: UUID) -> String? {
        guard let data = Thumbnailer.jpegData(from: image) else {
            Log.history.error("Failed to encode thumbnail for \(id.uuidString, privacy: .public)")
            return nil
        }
        let fileName = "\(id.uuidString).\(Constants.thumbnailFileExtension)"
        let url = thumbsURL.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return fileName
        } catch {
            Log.history.error("Failed to write thumbnail \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// 缩略图已存在则复用，否则按当前图片生成；返回缩略图文件名。
    private func existingOrGeneratedThumbnail(for image: CGImage, id: UUID) -> String? {
        let fileName = "\(id.uuidString).\(Constants.thumbnailFileExtension)"
        if fileManager.fileExists(atPath: thumbsURL.appendingPathComponent(fileName).path) {
            return fileName
        }
        return writeThumbnail(for: image, id: id)
    }

    /// 删除记录对应的图片与缩略图，失败只记日志。
    private func removeFiles(for items: [HistoryItem]) {
        for item in items {
            var urls = [imageURL(for: item)]
            if let thumbFileName = item.thumbFileName {
                urls.append(thumbsURL.appendingPathComponent(thumbFileName))
            }
            for url in urls {
                guard fileManager.fileExists(atPath: url.path) else { continue }
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    Log.history.error("Failed to remove history file \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func removeAllFiles(in directory: URL) {
        let fileURLs: [URL]
        do {
            fileURLs = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        } catch {
            Log.history.error("Failed to list history directory \(directory.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }
        for url in fileURLs {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                Log.history.error("Failed to remove history file \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// 老索引（#24 之前）没有 `thumbFileName` 时补生成缩略图并回写索引。
    @discardableResult
    private func backfillThumbnails() -> Bool {
        var updatedItems = items
        var changed = false
        for index in updatedItems.indices {
            let item = updatedItems[index]
            let existingThumbURL = item.thumbFileName.map { thumbsURL.appendingPathComponent($0) }
            if let existingThumbURL, fileManager.fileExists(atPath: existingThumbURL.path) {
                continue
            }
            guard let image = Self.decodeImage(at: imageURL(for: item)) else {
                Log.history.error("Cannot backfill thumbnail, image missing: \(item.fileName, privacy: .public)")
                continue
            }
            guard let thumbFileName = writeThumbnail(for: image, id: item.id) else {
                continue
            }
            updatedItems[index] = HistoryItem(
                id: item.id,
                createdAt: item.createdAt,
                source: item.source,
                pixelWidth: item.pixelWidth,
                pixelHeight: item.pixelHeight,
                fileName: item.fileName,
                isAnnotated: item.isAnnotated,
                thumbFileName: thumbFileName
            )
            changed = true
        }
        guard changed else { return false }
        items = updatedItems
        do {
            try writeIndex()
        } catch {
            Log.history.error("Failed to persist backfilled thumbnails: \(error.localizedDescription, privacy: .public)")
        }
        return true
    }

    private func postDidChange() {
        NotificationCenter.default.post(name: .historyStoreDidChange, object: nil)
    }

    private func writeIndex() throws {
        let data: Data
        do {
            data = try Self.encoder.encode(items)
        } catch {
            Log.history.error("Failed to encode history index: \(error.localizedDescription, privacy: .public)")
            throw HistoryError.indexWriteFailed
        }

        let tempURL = indexURL.appendingPathExtension(Constants.indexTempFileExtension)
        do {
            try data.write(to: tempURL)
            if fileManager.fileExists(atPath: indexURL.path) {
                _ = try fileManager.replaceItemAt(indexURL, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: indexURL)
            }
        } catch {
            try? fileManager.removeItem(at: tempURL)
            Log.history.error("Failed to write history index: \(error.localizedDescription, privacy: .public)")
            throw HistoryError.indexWriteFailed
        }
    }

    private func createDirectoriesIfNeeded() {
        for directory in [rootURL, imagesURL, thumbsURL] {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                Log.history.error("Failed to create history directory \(directory.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func load() {
        guard fileManager.fileExists(atPath: indexURL.path) else {
            Log.history.notice("History index missing, rebuilding from images")
            rebuildIndex()
            return
        }

        do {
            let data = try Data(contentsOf: indexURL)
            items = try Self.decoder.decode([HistoryItem].self, from: data)
            Log.history.info("Loaded \(self.items.count, privacy: .public) history item(s)")
        } catch {
            Log.history.error("History index corrupt, rebuilding from images: \(error.localizedDescription, privacy: .public)")
            rebuildIndex()
            return
        }

        backfillThumbnails()
        pruneOverflow()
    }

    /// 加载历史后按当前 `historyLimit` 剪枝（例如上限被调小），保持约束一致。
    private func pruneOverflow() {
        guard items.count > historyLimit else { return }
        let original = items
        let overflow = Array(items.dropFirst(historyLimit))
        items = Array(items.prefix(historyLimit))
        do {
            try writeIndex()
        } catch {
            // 索引没写成功就不能删文件，否则磁盘索引会指向已删除的图片。
            Log.history.error("Failed to persist pruned history index: \(error.localizedDescription, privacy: .public)")
            items = original
            return
        }
        removeFiles(for: overflow)
        Log.history.notice("Pruned \(overflow.count, privacy: .public) history item(s) over limit")
    }

    /// 扫描 `images/` 重建索引。文件名即记录 id；像素尺寸从 PNG 解出；创建时间取文件修改时间。
    /// 缩略图缺失时一并补生成；超过 `historyLimit` 的旧记录连同文件清理。
    private func rebuildIndex() {
        let fileURLs: [URL]
        do {
            fileURLs = try fileManager.contentsOfDirectory(
                at: imagesURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            Log.history.error("Failed to scan history images: \(error.localizedDescription, privacy: .public)")
            items = []
            return
        }

        var rebuilt: [HistoryItem] = []
        for fileURL in fileURLs where fileURL.pathExtension.lowercased() == Constants.imageFileExtension {
            guard let id = UUID(uuidString: fileURL.deletingPathExtension().lastPathComponent) else {
                Log.history.notice("Skipping history image with non-UUID file name: \(fileURL.lastPathComponent, privacy: .public)")
                continue
            }
            guard let image = Self.decodeImage(at: fileURL) else {
                Log.history.error("Skipping undecodable history image: \(fileURL.lastPathComponent, privacy: .public)")
                continue
            }

            let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            let createdAt = resourceValues?.contentModificationDate ?? Date()
            rebuilt.append(
                HistoryItem(
                    id: id,
                    createdAt: createdAt,
                    source: .unknown,
                    pixelWidth: image.width,
                    pixelHeight: image.height,
                    fileName: fileURL.lastPathComponent,
                    isAnnotated: false,
                    thumbFileName: existingOrGeneratedThumbnail(for: image, id: id)
                )
            )
        }

        rebuilt.sort { $0.createdAt > $1.createdAt }
        let overflow = Array(rebuilt.dropFirst(historyLimit))
        items = Array(rebuilt.prefix(historyLimit))
        do {
            try writeIndex()
        } catch {
            Log.history.error("Failed to persist rebuilt history index: \(error.localizedDescription, privacy: .public)")
            items = rebuilt
            removeFiles(for: [])
            postDidChange()
            return
        }
        removeFiles(for: overflow)
        Log.history.notice("Rebuilt history index with \(self.items.count, privacy: .public) item(s)")
        postDidChange()
    }

    private static func decodeImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    // MARK: - 编码

    // 用 Foundation 默认的 Date 编码（timeIntervalSinceReferenceDate），保证 append → load 精确回同一条。
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()
}
