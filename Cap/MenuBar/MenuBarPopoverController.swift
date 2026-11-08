import AppKit
import SwiftUI

/// 菜单栏 popover 控制器：构建依赖真实数据的 model，管理显示与收起。
@MainActor
final class MenuBarPopoverController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private let model = MenuBarPopoverModel()

    private let historyStore: HistoryStore
    private let settings: SettingsStore
    private let launchAtLogin: LaunchAtLoginControlling

    var onOpenHistory: (() -> Void)?
    var onQuit: (() -> Void)?

    private let maximumThumbnails = 8

    init(
        historyStore: HistoryStore,
        settings: SettingsStore,
        launchAtLogin: LaunchAtLoginControlling
    ) {
        self.historyStore = historyStore
        self.settings = settings
        self.launchAtLogin = launchAtLogin
        super.init()

        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: MenuBarPopoverView(model: model))
        popover.contentSize = NSSize(width: 320, height: 360)
        wireActions()
        observeHistoryChanges()
    }

    var isShown: Bool { popover.isShown }

    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            refreshModel()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func close() {
        popover.performClose(nil)
    }

    // MARK: - 数据

    private func wireActions() {
        model.onRefresh = { [weak self] in self?.refreshModel() }
        model.onCopy = { [weak self] id in self?.copyItem(id: id) }
        model.onOpenHistory = { [weak self] in
            self?.close()
            self?.onOpenHistory?()
        }
        model.onQuit = { [weak self] in self?.onQuit?() }
        model.onOpenPermissionSettings = {
            ScreenRecordingPermissionModel().openSystemSettings()
        }
        model.onChooseDirectory = { [weak self] in self?.chooseDirectory() }
        model.onChangeFormat = { [weak self] format in
            self?.settings.imageFormat = format
            self?.refreshModel()
        }
        model.onToggleLaunchAtLogin = { [weak self] enabled in self?.toggleLaunchAtLogin(enabled) }
    }

    private var historyObserver: NSObjectProtocol?

    private func observeHistoryChanges() {
        guard historyObserver == nil else { return }
        historyObserver = NotificationCenter.default.addObserver(
            forName: .historyStoreDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.refreshModel()
        }
    }

    private func refreshModel() {
        model.permissionGranted = CGPreflightScreenCaptureAccess()
        model.imageFormat = settings.imageFormat
        model.saveDirectoryPath = settings.saveDirectory.path
        model.launchAtLogin = launchAtLogin.isEnabled
        model.thumbnails = recentThumbnails()
        model.errorMessage = nil
    }

    private func recentThumbnails() -> [PopoverThumbnail] {
        let items = historyStore.recentItems(limit: maximumThumbnails)
        return items.compactMap { item in
            let url = historyStore.thumbnailURL(for: item) ?? historyStore.imageURL(for: item)
            guard let image = NSImage(contentsOf: url) else { return nil }
            image.size = NSSize(width: 64, height: 44)
            return PopoverThumbnail(id: item.id, image: image, isAnnotated: item.isAnnotated)
        }
    }

    private func copyItem(id: UUID) {
        guard let item = historyStore.items.first(where: { $0.id == id }) else { return }
        guard let data = historyStore.imageData(for: item),
              let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            model.errorMessage = "无法读取这张截图"
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
        pasteboard.setData(tiff, forType: .tiff)
        Log.history.notice("Copied history item from popover: \(item.id.uuidString, privacy: .public)")
        close()
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.saveDirectory
        panel.prompt = "选择保存目录"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.saveDirectory = url
        refreshModel()
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLogin.setEnabled(enabled)
        } catch {
            model.errorMessage = "登录自启设置失败：\(error.localizedDescription)"
        }
        refreshModel()
    }
}
