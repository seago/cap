import AppKit
import CoreGraphics
import Foundation

/// 图片保存格式，见 `DESIGN.md` §3.5：PNG 默认（无损），JPEG 可选。
enum ImageFormat: String, CaseIterable, Codable, Sendable {
    case png
    case jpeg

    /// 落地文件扩展名：PNG 用 `png`，JPEG 用 macOS 上更常见的 `jpg`。
    var fileExtension: String {
        switch self {
        case .png:
            return "png"
        case .jpeg:
            return "jpg"
        }
    }
}

enum FileExportError: LocalizedError, Equatable {
    case encodingFailed
    case directoryCreationFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return String(localized: "无法编码要保存的图片。")
        case .directoryCreationFailed:
            return String(localized: "无法创建保存目录。")
        case .writeFailed:
            return String(localized: "无法写入保存文件。")
        }
    }
}

/// 把标注版图片写到保存目录，见 `DESIGN.md` §3.5 / §6.3：
///
/// - 默认目录 `~/Pictures/Screenshots/`，不存在则自动创建
/// - 文件名来自 `FileNaming`（本地时间，重名追加 ` 2`、` 3`）
/// - `Data.write(options: .atomic)` = 临时文件 + rename，避免留下半张图
struct FileExporter {
    /// `~/Pictures/Screenshots/`（沙盒下也解析到真实用户目录）
    static var defaultDirectory: URL {
        UserHome.picturesDirectory.appendingPathComponent("Screenshots", isDirectory: true)
    }

    let directory: URL
    let format: ImageFormat
    /// JPEG 压缩质量，`DESIGN.md` §3.5 默认 0.85；PNG 忽略。
    let jpegQuality: CGFloat
    private let fileManager: FileManager

    init(
        directory: URL = FileExporter.defaultDirectory,
        format: ImageFormat = .png,
        jpegQuality: CGFloat = 0.85,
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.format = format
        self.jpegQuality = jpegQuality
        self.fileManager = fileManager
    }

    /// 编码 `image` 并保存到 `directory`，返回最终文件 URL（重名时已带序号）。
    @discardableResult
    func save(_ image: CGImage, at date: Date = Date()) throws -> URL {
        guard let data = encodedData(for: image) else {
            throw FileExportError.encodingFailed
        }

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw FileExportError.directoryCreationFailed
        }

        let fileName = FileNaming.sanitize(
            FileNaming.fileName(for: date, fileExtension: format.fileExtension)
        )
        let url = FileNaming.uniqueURL(in: directory, fileName: fileName, fileManager: fileManager)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw FileExportError.writeFailed
        }
        return url
    }

    private func encodedData(for image: CGImage) -> Data? {
        let representation = NSBitmapImageRep(cgImage: image)
        switch format {
        case .png:
            return representation.representation(using: .png, properties: [:])
        case .jpeg:
            return representation.representation(
                using: .jpeg,
                properties: [.compressionFactor: jpegQuality]
            )
        }
    }
}
