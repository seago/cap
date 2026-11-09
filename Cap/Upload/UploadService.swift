import Foundation

/// 上传目标配置（用户自己的 HTTP 端点；不内置任何图床）。
struct UploadConfiguration: Equatable, Sendable {
    /// 完整端点 URL，例如 `https://example.com/upload`。
    var endpoint: URL
    /// multipart 的文件字段名，默认 `file`。
    var fieldName: String = "file"
    /// 可选鉴权头的值，例如 `Bearer xxx`；作为 `Authorization` 头发送。
    var authorization: String?
    /// 响应 JSON 中 URL 的字段名；留空时自动尝试 `url` / `link` / `data.url` 等，也接受纯文本 URL。
    var responseURLKey: String = ""

    init(
        endpoint: URL,
        fieldName: String = "file",
        authorization: String? = nil,
        responseURLKey: String = ""
    ) {
        self.endpoint = endpoint
        self.fieldName = fieldName
        self.authorization = authorization
        self.responseURLKey = responseURLKey
    }
}

enum UploadError: LocalizedError, Equatable {
    case notConfigured
    case invalidEndpoint
    case invalidImage
    case timedOut
    case transport(String)
    case requestFailed(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return String(localized: "未配置上传端点")
        case .invalidEndpoint: return String(localized: "上传端点 URL 无效")
        case .invalidImage: return String(localized: "图片数据无效")
        case .timedOut: return String(localized: "上传超时")
        case .transport(let message): return String(localized: "网络错误：\(message)")
        case .requestFailed(let statusCode): return String(localized: "请求失败（HTTP \(statusCode)）")
        case .invalidResponse: return String(localized: "上传结果不是有效链接")
        }
    }
}

/// 可替换的上传实现（`DESIGN.md` §10 的架构接缝）。
protocol Uploading: Sendable {
    func upload(
        _ data: Data,
        filename: String,
        mimeType: String,
        configuration: UploadConfiguration
    ) async throws -> URL
}

/// multipart/form-data 构造（纯函数，便于单测）。
enum MultipartFormData {
    static func make(
        boundary: String,
        fieldName: String,
        filename: String,
        mimeType: String,
        data: Data
    ) -> Data {
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename.utf8Escaped)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }
}

/// 解析上传响应里的 URL；支持 JSON 字段（含嵌套 `data.url`）与纯文本。
enum UploadResponseParser {
    static func url(from data: Data, contentType: String?, preferredKey: String) -> URL? {
        if let text = String(data: data, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if isHTTPURL(trimmed) {
                return URL(string: trimmed)
            }
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        var keys: [String] = []
        let preferred = preferredKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !preferred.isEmpty { keys.append(preferred) }
        keys.append(contentsOf: ["url", "link", "imageUrl", "image_url"])
        if let dictionary = json as? [String: Any] {
            for key in keys {
                if let value = dictionary[key] as? String,
                   let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
                   isHTTPURL(url.absoluteString) {
                    return url
                }
            }
            if let nested = dictionary["data"] as? [String: Any] {
                for key in keys {
                    if let value = nested[key] as? String,
                       let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
                       isHTTPURL(url.absoluteString) {
                        return url
                    }
                }
            }
        }
        return nil
    }

    private static func isHTTPURL(_ string: String) -> Bool {
        guard let url = URL(string: string), let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && url.host != nil
    }
}

/// URLSession 实现：multipart POST，超时/网络错误/5xx 重试 1 次。
struct HTTPUploadService: Uploading {
    private let session: URLSession
    private let timeout: TimeInterval

    init(session: URLSession? = nil, timeout: TimeInterval = 30) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = timeout
            configuration.timeoutIntervalForResource = timeout
            self.session = URLSession(configuration: configuration)
        }
        self.timeout = timeout
    }

    func upload(
        _ data: Data,
        filename: String,
        mimeType: String,
        configuration: UploadConfiguration
    ) async throws -> URL {
        guard !data.isEmpty else { throw UploadError.invalidImage }
        let boundary = "CapBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Cap/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        if let authorization = configuration.authorization?.trimmingCharacters(in: .whitespacesAndNewlines),
           !authorization.isEmpty {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = MultipartFormData.make(
            boundary: boundary,
            fieldName: configuration.fieldName,
            filename: filename,
            mimeType: mimeType,
            data: data
        )
        request.timeoutInterval = timeout

        var lastError: UploadError = .transport("unknown")
        for attempt in 0...1 {
            do {
                let (responseData, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    lastError = .invalidResponse
                    continue
                }
                guard (200..<300).contains(http.statusCode) else {
                    lastError = .requestFailed(statusCode: http.statusCode)
                    // 4xx 不重试（配置/鉴权问题重试无意义），只对 5xx 重试。
                    if (400..<500).contains(http.statusCode) || attempt == 1 {
                        throw lastError
                    }
                    continue
                }
                guard let url = UploadResponseParser.url(
                    from: responseData,
                    contentType: http.value(forHTTPHeaderField: "Content-Type"),
                    preferredKey: configuration.responseURLKey
                ) else {
                    throw UploadError.invalidResponse
                }
                return url
            } catch let error as UploadError {
                if attempt == 0, !isRetryable(error) {
                    throw error
                }
                lastError = error
            } catch let error as URLError {
                if error.code == .timedOut {
                    lastError = .timedOut
                } else {
                    lastError = .transport(error.localizedDescription)
                }
                if attempt == 0 { continue }
                throw lastError
            } catch {
                lastError = .transport(error.localizedDescription)
                if attempt == 0 { continue }
                throw lastError
            }
        }
        throw lastError
    }

    private func isRetryable(_ error: UploadError) -> Bool {
        switch error {
        case .timedOut, .transport:
            return true
        case .requestFailed(let statusCode):
            return (500..<600).contains(statusCode)
        case .notConfigured, .invalidEndpoint, .invalidImage, .invalidResponse:
            return false
        }
    }
}

private extension String {
    /// multipart 文件名里的引号/换行转义（够用即可）。
    var utf8Escaped: String {
        replacingOccurrences(of: "\"", with: "%22")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}
