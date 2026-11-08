import Foundation
import ServiceManagement

/// 登录自启控制，便于单测注入假实现。
@MainActor
protocol LaunchAtLoginControlling {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

/// 基于 `SMAppService.mainApp` 的真实实现（macOS 13+）。
@MainActor
struct LaunchAtLoginController: LaunchAtLoginControlling {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
