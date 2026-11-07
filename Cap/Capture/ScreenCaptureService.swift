import AppKit
import CoreGraphics
import ScreenCaptureKit

/// 截取的坐标/样式选项，便于单测（不依赖 SCShareableContent）。
struct CaptureOptions: Equatable, Sendable {
    /// 窗口截取是否包含阴影（默认包含）。
    var includeWindowShadow: Bool = true
    /// 是否包含鼠标光标（截图一律不带）。
    var showsCursor: Bool = false

    static let windowDefault = CaptureOptions()
    static let windowWithoutShadow = CaptureOptions(includeWindowShadow: false)
}

@MainActor
final class ScreenCaptureService {
    // MARK: - 全屏

    func capture(_ request: CaptureRequest) async throws -> CGImage {
        let content = try await shareableContent()
        guard let display = content.displays.first(where: { $0.displayID == request.displayID }) else {
            throw CaptureError.displayNotFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = Self.displayConfiguration(width: Int(display.width), height: Int(display.height))
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }

    // MARK: - 区域

    /// 区域截取：`rect` 使用 CoreGraphics 全局屏幕坐标（点，原点主屏左上，跨显示器）。
    func capture(region: CGRect) async throws -> CGImage {
        guard CGPreflightScreenCaptureAccess() else {
            throw CaptureError.permissionDenied
        }
        guard region.width >= 1, region.height >= 1 else {
            throw CaptureError.invalidRegion
        }
        do {
            return try await SCScreenshotManager.captureImage(in: region)
        } catch {
            Log.capture.error("Region capture failed: \(error.localizedDescription, privacy: .public)")
            throw CaptureError.captureFailed
        }
    }

    // MARK: - 窗口

    func capture(windowID: CGWindowID, options: CaptureOptions = .windowDefault) async throws -> CGImage {
        let content = try await shareableContent()
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            throw CaptureError.windowNotFound
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = Self.windowConfiguration(
            width: Int(window.frame.width),
            height: Int(window.frame.height),
            options: options
        )
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }

    // MARK: - 配置构造（可单测）

    static func displayConfiguration(width: Int, height: Int) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = width
        configuration.height = height
        configuration.showsCursor = false
        return configuration
    }

    static func windowConfiguration(width: Int, height: Int, options: CaptureOptions) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = width
        configuration.height = height
        configuration.showsCursor = options.showsCursor
        // 默认保留窗口阴影；Option 点击时不带阴影。
        configuration.ignoreShadowsSingleWindow = !options.includeWindowShadow
        return configuration
    }

    // MARK: - 辅助

    private func shareableContent() async throws -> SCShareableContent {
        guard CGPreflightScreenCaptureAccess() else {
            throw CaptureError.permissionDenied
        }
        do {
            return try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            Log.capture.error("SCShareableContent failed: \(error.localizedDescription, privacy: .public)")
            throw CaptureError.permissionDenied
        }
    }

    static func displayUnderMouse() -> CGDirectDisplayID? {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        return screen?.displayID
    }

    /// 主屏高度，用于 AppKit（左下原点）与 CoreGraphics（左上原点）坐标系互转。
    static func mainScreenHeight() -> CGFloat {
        NSScreen.screens.first?.frame.maxY ?? 0
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
