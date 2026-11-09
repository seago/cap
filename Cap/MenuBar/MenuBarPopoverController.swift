import AppKit
import SwiftUI

/// 菜单栏 popover 控制器：构建依赖真实数据的 model，管理显示与收起。
@MainActor
final class MenuBarPopoverController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private let model = MenuBarPopoverModel()
    private lazy var hostingController = NSHostingController(rootView: MenuBarPopoverView(model: model))

    private let historyStore: HistoryStore
    private let settings: SettingsStore
    private let launchAtLogin: LaunchAtLoginControlling

    var onOpenHistory: (() -> Void)?
    var onScrollCapture: (() -> Void)?
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

        // 让 popover 跟着 SwiftUI 内容真实高度走；固定 contentSize 会让窗口按左下图钉住，
        // 内容变矮时整个 popover 顶部往下掉（表现为离菜单栏很远）。
        hostingController.sizingOptions = [.preferredContentSize]
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = hostingController
        wireActions()
        observeHistoryChanges()
    }

    var isShown: Bool { popover.isShown }

    /// 内容（例如展开设置区）变化后同步 popover 尺寸。
    private func updatePopoverSize() {
        let size = hostingController.preferredContentSize
        guard size.width > 0, size.height > 0 else { return }
        if popover.contentSize != size {
            popover.contentSize = size
        }
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            refreshModel()
            updatePopoverSize()
            NSApp.activate(ignoringOtherApps: true)
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
        model.onRevealInFinder = { [weak self] id in self?.revealInFinder(id: id) }
        model.onDelete = { [weak self] id in self?.deleteItem(id: id) }
        model.onClearAll = { [weak self] in self?.clearAllWithConfirmation() }
        model.onOpenHistory = { [weak self] in
            self?.close()
            self?.onOpenHistory?()
        }
        model.onScrollCapture = { [weak self] in
            self?.close()
            self?.onScrollCapture?()
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

    func refreshModel() {
        model.permissionGranted = CGPreflightScreenCaptureAccess()
        model.imageFormat = settings.imageFormat
        model.saveDirectoryPath = settings.saveDirectory.path
        let launchStatus = launchAtLogin.status
        model.launchAtLogin = launchStatus.isEnabled
        model.launchAtLoginNeedsApproval = launchStatus == .requiresApproval
        model.thumbnails = recentThumbnails()
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
        var failure: String?
        do {
            try enabled ? launchAtLogin.enable() : launchAtLogin.disable()
        } catch {
            failure = "登录自启设置失败：\(error.localizedDescription)"
        }
        refreshModel()
        if launchAtLogin.status == .requiresApproval {
            failure = "请在系统设置 → 通用 → 登录项中允许 Cap"
            launchAtLogin.openSystemSettings()
        }
        model.errorMessage = failure
    }

    private func revealInFinder(id: UUID) {
        guard let item = historyStore.items.first(where: { $0.id == id }) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([historyStore.imageURL(for: item)])
        close()
    }

    private func deleteItem(id: UUID) {
        do {
            try historyStore.delete(id: id)
        } catch {
            model.errorMessage = "删除失败：\(error.localizedDescription)"
        }
        refreshModel()
    }

    private func clearAllWithConfirmation() {
        let alert = NSAlert()
        alert.messageText = "清空全部历史截图？"
        alert.informativeText = "图片会从本机删除，操作不可撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try historyStore.clearAll()
        } catch {
            model.errorMessage = "清空失败：\(error.localizedDescription)"
        }
        refreshModel()
    }
}
