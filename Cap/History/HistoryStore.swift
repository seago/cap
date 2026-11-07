import CoreGraphics
import Foundation
import ImageIO

enum HistoryError: LocalizedError {
    case encodingFailed
    case imageWriteFailed
    case indexWriteFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "无法把截图编码为 PNG。"
        case .imageWriteFailed:
            return "无法写入历史图片文件。"
        case .indexWriteFailed:
            return "无法写入历史索引。"
        }
    }
}

/// 截图历史的本地存储，目录布局见 `DESIGN.md` §6.1：
///
/// ```
/// History/
/// ├─ index.json          // [HistoryItem]，新到旧
/// └─ images/{uuid}.png   // 原图
/// ```
///
/// 索引原子写（临时文件 + rename）；启动时加载，索引损坏或缺失则扫描 `images/` 重建。
/// 缩略图、剪枝、标注版替换不在 M0 范围内。
@MainActor
final class HistoryStore {
    private enum Constants {
        static let imagesDirectoryName = "images"
        static let indexFileName = "index.json"
        static let indexTempFileExtension = "tmp"
        static let imageFileExtension = "png"
    }

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
    let indexURL: URL

    /// 已加载的记录，新到旧。
    private(set) var items: [HistoryItem] = []

    init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        self.imagesURL = rootURL.appendingPathComponent(Constants.imagesDirectoryName, isDirectory: true)
        self.indexURL = rootURL.appendingPathComponent(Constants.indexFileName)
        createDirectoriesIfNeeded()
        load()
    }

    convenience init() {
        self.init(rootURL: Self.defaultRootURL)
    }

    // MARK: - 写入

    /// 把原图写为 `images/{uuid}.png` 并在索引最前面插入一条记录。
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

        let item = HistoryItem(
            id: id,
            createdAt: capturedAt,
            source: source,
            pixelWidth: image.width,
            pixelHeight: image.height,
            fileName: fileName,
            isAnnotated: false
        )
        items.insert(item, at: 0)
        do {
            try writeIndex()
        } catch {
            // 索引写失败时回滚内存与图片，保持与磁盘一致。
            items.removeAll { $0.id == id }
            try? fileManager.removeItem(at: imageURL)
            throw error
        }
        return item
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

    // MARK: - 读取

    private func createDirectoriesIfNeeded() {
        for directory in [rootURL, imagesURL] {
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
        }
    }

    /// 扫描 `images/` 重建索引。文件名即记录 id；像素尺寸从 PNG 解出；创建时间取文件修改时间。
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
                    isAnnotated: false
                )
            )
        }

        items = rebuilt.sorted { $0.createdAt > $1.createdAt }
        do {
            try writeIndex()
        } catch {
            Log.history.error("Failed to persist rebuilt history index: \(error.localizedDescription, privacy: .public)")
        }
        Log.history.notice("Rebuilt history index with \(self.items.count, privacy: .public) item(s)")
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
