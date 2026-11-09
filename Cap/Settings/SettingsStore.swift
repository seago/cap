import Foundation

/// 用户设置（UserDefaults 封装），可注入 defaults 便于单测。
@MainActor
final class SettingsStore {
    enum Key {
        static let saveDirectory = "saveFolderPath"
        static let imageFormat = "imageFormat"
        static let jpegQuality = "jpegQuality"
        static let launchAtLoginDefaultApplied = "launchAtLoginDefaultApplied"
    }

    /// 快捷键设置变化（popover 需要刷新、AppDelegate 需要重绑）。
    static let hotKeyDidChangeNotification = Notification.Name("CapHotKeyDidChange")

    static let defaultDirectory: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures/Screenshots", isDirectory: true)

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 保存目录；目录为空、路径不存在或不是目录时回退默认目录。
    var saveDirectory: URL {
        get {
            guard let path = defaults.string(forKey: Key.saveDirectory), !path.isEmpty else {
                return Self.defaultDirectory
            }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                return Self.defaultDirectory
            }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set {
            defaults.set(newValue.path, forKey: Key.saveDirectory)
        }
    }

    /// DESIGN §6.2 默认登录自启：首次启动时自动注册一次，之后尊重用户选择。
    var shouldApplyDefaultLaunchAtLogin: Bool {
        !defaults.bool(forKey: Key.launchAtLoginDefaultApplied)
    }

    func markDefaultLaunchAtLoginApplied() {
        defaults.set(true, forKey: Key.launchAtLoginDefaultApplied)
    }

    var imageFormat: ImageFormat {
        get {
            guard let raw = defaults.string(forKey: Key.imageFormat),
                  let format = ImageFormat(rawValue: raw) else {
                return .png
            }
            return format
        }
        set { defaults.set(newValue.rawValue, forKey: Key.imageFormat) }
    }

    var jpegQuality: CGFloat {
        get {
            let value = defaults.object(forKey: Key.jpegQuality) as? Double
            guard let value, value > 0, value <= 1 else { return 0.85 }
            return CGFloat(value)
        }
        set { defaults.set(Double(newValue), forKey: Key.jpegQuality) }
    }

    /// 历史条数上限（v1 不暴露修改，见 DESIGN §6.2）。
    var historyLimit: Int { 100 }

    // MARK: - 快捷键

    private func hotKeyKeys(for action: HotKeyAction) -> (keyCode: String, modifiers: String) {
        ("hotKey.\(action.rawValue).keyCode", "hotKey.\(action.rawValue).modifiers")
    }

    func hotKey(for action: HotKeyAction) -> HotKeyMapping {
        let keys = hotKeyKeys(for: action)
        guard let keyCode = defaults.object(forKey: keys.keyCode) as? Int,
              let modifiers = defaults.object(forKey: keys.modifiers) as? Int else {
            return action.defaultMapping
        }
        return HotKeyMapping(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))
    }

    func allHotKeys() -> [HotKeyAction: HotKeyMapping] {
        var result: [HotKeyAction: HotKeyMapping] = [:]
        for action in HotKeyAction.allCases {
            result[action] = hotKey(for: action)
        }
        return result
    }

    /// 该组合是否已经被其它动作占用。
    func hotKeyConflict(_ mapping: HotKeyMapping, excluding action: HotKeyAction) -> HotKeyAction? {
        for other in HotKeyAction.allCases where other != action {
            if hotKey(for: other) == mapping {
                return other
            }
        }
        return nil
    }

    func setHotKey(_ mapping: HotKeyMapping, for action: HotKeyAction) {
        let keys = hotKeyKeys(for: action)
        defaults.set(Int(mapping.keyCode), forKey: keys.keyCode)
        defaults.set(Int(mapping.modifiers), forKey: keys.modifiers)
        NotificationCenter.default.post(name: Self.hotKeyDidChangeNotification, object: action)
    }

    func resetHotKey(for action: HotKeyAction) {
        let keys = hotKeyKeys(for: action)
        defaults.removeObject(forKey: keys.keyCode)
        defaults.removeObject(forKey: keys.modifiers)
        NotificationCenter.default.post(name: Self.hotKeyDidChangeNotification, object: action)
    }
}

extension ImageFormat {
    var displayName: String {
        switch self {
        case .png: return "PNG（无损）"
        case .jpeg: return "JPEG（质量 0.85）"
        }
    }

}
