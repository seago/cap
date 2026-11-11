import Foundation

/// 仅用于自动化验收的隐藏开关（Release 构建中恒为 false）。
///
/// Debug 下可用 `CAP_EDITOR_CAPTURABLE=1` 让编辑器/钉屏窗口进入 screencapture，
/// 便于截图验收；App Store/Release 构建不保留该行为。
enum TestHooks {
    static var editorCapturable: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["CAP_EDITOR_CAPTURABLE"] == "1"
        #else
        false
        #endif
    }
}
