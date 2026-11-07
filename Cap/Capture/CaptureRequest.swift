import CoreGraphics
import Foundation

struct CaptureRequest: Equatable, Sendable {
    let displayID: CGDirectDisplayID
}

enum CaptureError: LocalizedError, Equatable {
    case permissionDenied
    case displayNotFound
    case encodingFailed
    case clipboardWriteFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Cap 没有屏幕录制权限。请在系统设置中授权后重试。"
        case .displayNotFound:
            return "找不到鼠标所在的显示器。"
        case .encodingFailed:
            return "无法把截图编码为 PNG / TIFF。"
        case .clipboardWriteFailed:
            return "无法写入剪贴板。"
        }
    }
}
