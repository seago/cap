import AppKit

/// 菜单栏图标与 popover。
@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let settings: SettingsStore
    private let popoverController: MenuBarPopoverController

    /// 打开历史窗口（AppDelegate 注入）。
    var onOpenHistory: (() -> Void)?
    /// 开始滚动长截图（AppDelegate 注入）。
    var onScrollCapture: (() -> Void)?
    /// 修改快捷键（AppDelegate 注入，返回是否注册成功）。
    var onHotKeyChange: ((HotKeyAction, HotKeyMapping) -> Bool)?

    init(
        historyStore: HistoryStore,
        settings: SettingsStore,
        launchAtLogin: LaunchAtLoginControlling
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.settings = settings
        popoverController = MenuBarPopoverController(
            historyStore: historyStore,
            settings: settings,
            launchAtLogin: launchAtLogin
        )
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Cap")
            image?.isTemplate = true
            button.image = image
            button.toolTip = String(localized: "Cap · \(settings.hotKey(for: .capture).displayString) 截图")
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp])
        }

        popoverController.onOpenHistory = { [weak self] in
            self?.onOpenHistory?()
        }
        popoverController.onScrollCapture = { [weak self] in
            self?.onScrollCapture?()
        }
        popoverController.onHotKeyChange = { [weak self] action, mapping in
            self?.onHotKeyChange?(action, mapping) ?? false
        }
        popoverController.onQuit = {
            NSApp.terminate(nil)
        }

        refreshPermissionIndicator()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    /// 权限缺失时菜单栏图标呈橙色警示，恢复后复原。
    func refreshPermissionIndicator() {
        guard let button = statusItem.button else { return }
        let imageName = CGPreflightScreenCaptureAccess() ? "camera.viewfinder" : "exclamationmark.circle"
        let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Cap")
        image?.isTemplate = true
        button.image = image
        button.contentTintColor = CGPreflightScreenCaptureAccess() ? nil : .systemOrange
        button.toolTip = CGPreflightScreenCaptureAccess()
            ? String(localized: "Cap · \(settings.hotKey(for: .capture).displayString) 截图")
            : String(localized: "Cap · 缺少屏幕录制权限，点击查看")
    }

    /// 截图保存成功后短暂显示对勾。
    func flashSaved() {
        guard let button = statusItem.button else { return }
        let checkmark = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: String(localized: "已保存"))
        checkmark?.isTemplate = false
        button.image = checkmark
        button.contentTintColor = .systemGreen
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self.refreshPermissionIndicator()
        }
    }

    @objc private func applicationDidBecomeActive() {
        refreshPermissionIndicator()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        let screen = button.window?.screen?.frame ?? .zero
        Log.app.debug("Popover anchor button=frame=\(String(describing: button.frame), privacy: .public) window=\(String(describing: button.window?.frame), privacy: .public) screen=\(String(describing: screen), privacy: .public)")
        popoverController.toggle(relativeTo: button)
    }
}
