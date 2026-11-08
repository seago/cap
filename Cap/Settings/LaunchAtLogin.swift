import Foundation
import ServiceManagement

/// 登录自启的对外状态。
enum LaunchAtLoginStatus: Equatable, Sendable {
    case enabled
    case disabled
    /// 用户已在系统设置里关闭、但系统仍保留注册记录；需要用户去系统设置重新允许。
    case requiresApproval
    /// 无法判断（当前用户环境或系统版本不支持）。
    case unavailable

    var isEnabled: Bool { self == .enabled }
}

/// 登录自启控制，便于单测注入假实现。
@MainActor
protocol LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus { get }
    func enable() throws
    func disable() throws
    /// 打开系统设置的登录项面板（requiresApproval 时引导用户）。
    func openSystemSettings()
}

/// 基于 `SMAppService.mainApp` 的真实实现（macOS 13+）。
///
/// 注意 `SMAppService` 的状态机：
/// - `.notRegistered` → 直接 `register()`
/// - `.requiresApproval` → 用户关闭过登录项，重复 `register()` 会抛 `kSMErrorAlreadyRegistered`，
///   只能引导用户去系统设置重新勾选
/// - `.enabled` → 已经启用，重复注册会抛错，直接视为成功
@MainActor
struct LaunchAtLoginController: LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered:
            return .disabled
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    func enable() throws {
        switch SMAppService.mainApp.status {
        case .enabled:
            return
        case .requiresApproval:
            openSystemSettings()
        case .notRegistered, .notFound:
            try SMAppService.mainApp.register()
        @unknown default:
            try SMAppService.mainApp.register()
        }
    }

    func disable() throws {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            return
        case .enabled, .requiresApproval:
            try SMAppService.mainApp.unregister()
        case .notFound:
            return
        @unknown default:
            try SMAppService.mainApp.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
