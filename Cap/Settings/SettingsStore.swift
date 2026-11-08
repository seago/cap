import Foundation

/// 用户设置（UserDefaults 封装），可注入 defaults 便于单测。
@MainActor
final class SettingsStore {
    enum Key {
        static let saveDirectory = "saveFolderPath"
        static let imageFormat = "imageFormat"
        static let jpegQuality = "jpegQuality"
    }

    static let defaultDirectory: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures/Screenshots", isDirectory: true)

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 保存目录；目录为空或不存在时回退默认目录。
    var saveDirectory: URL {
        get {
            guard let path = defaults.string(forKey: Key.saveDirectory), !path.isEmpty else {
                return Self.defaultDirectory
            }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set {
            defaults.set(newValue.path, forKey: Key.saveDirectory)
        }
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
}

extension ImageFormat {
    var displayName: String {
        switch self {
        case .png: return "PNG（无损）"
        case .jpeg: return "JPEG（质量 0.85）"
        }
    }
}
