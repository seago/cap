import AppKit

/// 菜单栏图标与 popover。
@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popoverController: MenuBarPopoverController

    /// 打开历史窗口（AppDelegate 注入）。
    var onOpenHistory: (() -> Void)?

    init(
        historyStore: HistoryStore,
        settings: SettingsStore,
        launchAtLogin: LaunchAtLoginControlling
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
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
            button.toolTip = "Cap · ⌘⇧2 截图"
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp])
        }

        popoverController.onOpenHistory = { [weak self] in
            self?.onOpenHistory?()
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
            ? "Cap · ⌘⇧2 截图"
            : "Cap · 缺少屏幕录制权限，点击查看"
    }

    /// 截图保存成功后短暂显示对勾。
    func flashSaved() {
        guard let button = statusItem.button else { return }
        let checkmark = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "已保存")
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
        popoverController.toggle(relativeTo: button)
    }
}
