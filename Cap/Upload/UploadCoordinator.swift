import AppKit
import CoreGraphics

/// 把「配置 → 编码 → 上传 → 复制链接」串起来；窗口/编辑器只负责展示结果。
@MainActor
final class UploadCoordinator {
    private let settings: UploadSettingsStore
    private let service: Uploading
    private let clipboardWriter: ClipboardWriter
    private let historyStore: HistoryStore

    init(
        settings: UploadSettingsStore,
        service: Uploading = HTTPUploadService(),
        clipboardWriter: ClipboardWriter = ClipboardWriter(),
        historyStore: HistoryStore
    ) {
        self.settings = settings
        self.service = service
        self.clipboardWriter = clipboardWriter
        self.historyStore = historyStore
    }

    var isConfigured: Bool { settings.isConfigured }

    /// 上传 PNG 数据并把返回的 URL 复制到剪贴板；可选写回历史记录。
    @discardableResult
    func uploadPNG(
        _ data: Data,
        filename: String,
        historyItemID: UUID? = nil
    ) async throws -> URL {
        guard let configuration = settings.configuration else {
            throw UploadError.notConfigured
        }
        let url = try await service.upload(
            data,
            filename: filename,
            mimeType: "image/png",
            configuration: configuration
        )
        try clipboardWriter.writeText(url.absoluteString)
        if let historyItemID {
            _ = try? historyStore.setUploadedURL(id: historyItemID, url: url.absoluteString)
        }
        Log.upload.notice("Uploaded image to \(url.absoluteString, privacy: .public)")
        return url
    }

    /// 上传一条历史截图（读取磁盘上的最终版）。
    @discardableResult
    func uploadHistoryItem(_ item: HistoryItem) async throws -> URL {
        guard let image = historyStore.loadImage(for: item) else {
            throw UploadError.invalidImage
        }
        guard let data = ImageEncoder.pngData(from: image) else {
            throw UploadError.invalidImage
        }
        return try await uploadPNG(data, filename: "\(item.id.uuidString).png", historyItemID: item.id)
    }
}
