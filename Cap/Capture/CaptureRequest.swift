import CoreGraphics
import Foundation

struct CaptureRequest: Equatable, Sendable {
    let displayID: CGDirectDisplayID
}

enum CaptureError: LocalizedError, Equatable {
    case permissionDenied
    case displayNotFound
    case windowNotFound
    case invalidRegion
    case captureFailed
    case encodingFailed
    case clipboardWriteFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return String(localized: "Cap 没有屏幕录制权限。请在系统设置中授权后重试。")
        case .displayNotFound:
            return String(localized: "找不到鼠标所在的显示器。")
        case .windowNotFound:
            return String(localized: "找不到要截取的窗口。")
        case .invalidRegion:
            return String(localized: "选区太小，无法截取。")
        case .captureFailed:
            return String(localized: "截图失败，请重试。")
        case .encodingFailed:
            return String(localized: "无法把截图编码为 PNG / TIFF。")
        case .clipboardWriteFailed:
            return String(localized: "无法写入剪贴板。")
        }
    }
}
