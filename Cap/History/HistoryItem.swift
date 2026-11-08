import CoreGraphics
import Foundation

/// 一条历史记录的来源。
///
/// 对应 `DESIGN.md` §5.3 的 `CaptureSource` 的可持久化形态；M0 只会产生 `.display`。
/// 索引损坏后从 `images/` 重建时来源不可知，记为 `.unknown`。
enum HistorySource: Codable, Equatable, Sendable {
    case region(CGRect)
    case window(CGWindowID)
    case display(CGDirectDisplayID)
    case unknown
}

extension HistorySource {
    private enum CodingKeys: String, CodingKey {
        case type
        case rect
        case windowID
        case displayID
    }

    private enum Kind: String, Codable {
        case region
        case window
        case display
        case unknown
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .region:
            self = .region(try container.decode(CGRect.self, forKey: .rect))
        case .window:
            self = .window(try container.decode(CGWindowID.self, forKey: .windowID))
        case .display:
            self = .display(try container.decode(CGDirectDisplayID.self, forKey: .displayID))
        case .unknown:
            self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .region(let rect):
            try container.encode(Kind.region, forKey: .type)
            try container.encode(rect, forKey: .rect)
        case .window(let windowID):
            try container.encode(Kind.window, forKey: .type)
            try container.encode(windowID, forKey: .windowID)
        case .display(let displayID):
            try container.encode(Kind.display, forKey: .type)
            try container.encode(displayID, forKey: .displayID)
        case .unknown:
            try container.encode(Kind.unknown, forKey: .type)
        }
    }
}

/// `index.json` 中的一条历史记录，字段见 `DESIGN.md` §6.1。
struct HistoryItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let createdAt: Date
    let source: HistorySource
    /// 像素尺寸（不是 point）。
    let pixelWidth: Int
    let pixelHeight: Int
    /// 相对 `History/images/` 的文件名，形如 `{uuid}.png`。
    let fileName: String
    let isAnnotated: Bool
    /// 相对 `History/thumbs/` 的缩略图文件名，形如 `{uuid}.jpg`。
    ///
    /// #24 之前的索引没有该字段，解码后为 `nil`；`HistoryStore` 加载时会补生成缩略图。
    let thumbFileName: String?

    init(
        id: UUID,
        createdAt: Date,
        source: HistorySource,
        pixelWidth: Int,
        pixelHeight: Int,
        fileName: String,
        isAnnotated: Bool,
        thumbFileName: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.fileName = fileName
        self.isAnnotated = isAnnotated
        self.thumbFileName = thumbFileName
    }
}
