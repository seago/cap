import Foundation

/// 上传相关设置的 UserDefaults 封装；与 `SettingsStore` 分开，便于注入测试。
@MainActor
final class UploadSettingsStore {
    static let didChangeNotification = Notification.Name("CapUploadSettingsDidChange")

    enum Key {
        static let endpoint = "uploadEndpoint"
        static let fieldName = "uploadFieldName"
        static let authorization = "uploadAuthorization"
        static let responseURLKey = "uploadResponseURLKey"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var endpoint: String {
        get { defaults.string(forKey: Key.endpoint)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
        set { defaults.set(newValue, forKey: Key.endpoint); postChange() }
    }

    var fieldName: String {
        get {
            let value = defaults.string(forKey: Key.fieldName)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? "file" : value
        }
        set { defaults.set(newValue, forKey: Key.fieldName); postChange() }
    }

    var authorization: String {
        get { defaults.string(forKey: Key.authorization) ?? "" }
        set { defaults.set(newValue, forKey: Key.authorization); postChange() }
    }

    /// 响应 JSON 的 URL 字段名；留空自动识别。
    var responseURLKey: String {
        get { defaults.string(forKey: Key.responseURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
        set { defaults.set(newValue, forKey: Key.responseURLKey); postChange() }
    }

    /// 端点是否已配置且语法有效。
    var configuration: UploadConfiguration? {
        let trimmed = endpoint
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return nil
        }
        let auth = authorization.trimmingCharacters(in: .whitespacesAndNewlines)
        return UploadConfiguration(
            endpoint: url,
            fieldName: fieldName,
            authorization: auth.isEmpty ? nil : auth,
            responseURLKey: responseURLKey
        )
    }

    var isConfigured: Bool { configuration != nil }

    func reset() {
        defaults.removeObject(forKey: Key.endpoint)
        defaults.removeObject(forKey: Key.fieldName)
        defaults.removeObject(forKey: Key.authorization)
        defaults.removeObject(forKey: Key.responseURLKey)
        postChange()
    }

    private func postChange() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}
