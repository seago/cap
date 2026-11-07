import AppKit
import CoreGraphics

enum ScreenRecordingAccess: Equatable, Sendable {
    case notDetermined
    case granted
    case denied
    case restartRequired
}

@MainActor
protocol ScreenRecordingPermissionProviding {
    func preflight() -> Bool
    func request() -> Bool
    func openSystemSettings()
    func relaunch()
}

@MainActor
struct SystemScreenRecordingPermission: ScreenRecordingPermissionProviding {
    func preflight() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func request() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error {
                    Log.app.error("Relaunch failed: \(error.localizedDescription, privacy: .public)")
                }
                NSApp.terminate(nil)
            }
        }
    }
}

@MainActor
final class ScreenRecordingPermissionModel {
    private let provider: ScreenRecordingPermissionProviding
    private(set) var access: ScreenRecordingAccess = .notDetermined
    private var didRequest = false
    private var didOpenSettings = false

    init(provider: ScreenRecordingPermissionProviding = SystemScreenRecordingPermission()) {
        self.provider = provider
    }

    func refresh() {
        if provider.preflight() {
            access = .granted
        } else if didRequest || didOpenSettings {
            access = .denied
        } else {
            access = .notDetermined
        }
    }

    func request() {
        didRequest = true
        access = provider.request() ? .granted : .denied
    }

    func openSystemSettings() {
        didOpenSettings = true
        provider.openSystemSettings()
    }

    func recheck() {
        if provider.preflight() {
            access = .granted
        } else if didOpenSettings {
            access = .restartRequired
        } else if didRequest {
            access = .denied
        } else {
            access = .notDetermined
        }
    }

    func restartApp() {
        provider.relaunch()
    }
}
