import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var hotKeyCenters: [HotKeyAction: HotKeyCenter] = [:]
    private let pinnedImageController = PinnedImageController()
    private var onboardingController: OnboardingWindowController?

    private let screenCaptureService = ScreenCaptureService()
    private let clipboardWriter = ClipboardWriter()
    private let historyStore = HistoryStore()
    private let settings = SettingsStore()
    private let launchAtLogin = LaunchAtLoginController()
    private var historyWindowController: HistoryWindowController?
    private var selectionOverlay: SelectionOverlayController?
    private var editorController: EditorController?
    private var scrollCaptureController: ScrollCaptureController?
    private var scrollOverlay: ScrollCaptureOverlay?
    private var isSelectingScrollRegion = false
    private var isCapturing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("Cap launched, version \(AppInfo.version, privacy: .public)")
        Log.app.notice("Screen recording permission: \(CGPreflightScreenCaptureAccess(), privacy: .public)")
        let menuBarController = MenuBarController(
            historyStore: historyStore,
            settings: settings,
            launchAtLogin: launchAtLogin
        )
        menuBarController.onOpenHistory = { [weak self] in
            self?.openHistoryWindow()
        }
        menuBarController.onScrollCapture = { [weak self] in
            self?.beginScrollSelection()
        }
        menuBarController.onHotKeyChange = { [weak self] action, mapping in
            self?.applyHotKey(mapping, for: action) ?? false
        }
        self.menuBarController = menuBarController

        // DESIGN §6.2：首次启动默认开启登录自启；用户之后的选择优先。
        if settings.shouldApplyDefaultLaunchAtLogin {
            if launchAtLogin.status == .disabled {
                do {
                    try launchAtLogin.enable()
                } catch {
                    Log.app.error("Default launch-at-login registration failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            settings.markDefaultLaunchAtLoginApplied()
        }

        setUpHotKeys()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutRecordingBegan),
            name: .shortcutRecordingBegan,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutRecordingEnded),
            name: .shortcutRecordingEnded,
            object: nil
        )

        let onboardingController = OnboardingWindowController()
        onboardingController.showIfNeeded()
        self.onboardingController = onboardingController
    }

    func applicationWillTerminate(_ notification: Notification) {
        editorController?.close()
        scrollCaptureController?.cancel()
        pinnedImageController.closeAll()
        scrollOverlay?.dismiss()
        selectionOverlay?.dismiss()
        hotKeyCenters.values.forEach { $0.unregister() }
        Log.app.info("Cap terminating")
    }

    // MARK: - 全局快捷键

    /// 创建所有热键中心（只做一次），并按当前设置注册。
    private func setUpHotKeys() {
        for action in HotKeyAction.allCases where hotKeyCenters[action] == nil {
            let center = HotKeyCenter(identifier: action.identifier)
            center.onTrigger = { [weak self] in
                self?.handleHotKeyTrigger(action)
            }
            hotKeyCenters[action] = center
        }
        applyAllHotKeyMappings()
    }

    /// 按设置重新注册所有热键；被占用时回退默认值。
    private func applyAllHotKeyMappings() {
        for action in HotKeyAction.allCases {
            guard let center = hotKeyCenters[action] else { continue }
            let mapping = settings.hotKey(for: action)
            if center.register(mapping) { continue }
            Log.app.error("Failed to register \(action.rawValue, privacy: .public) hotkey \(mapping.displayString, privacy: .public)")
            settings.resetHotKey(for: action)
            if !center.register(action.defaultMapping) {
                Log.app.error("Failed to register default hotkey for \(action.rawValue, privacy: .public)")
            }
        }
    }

    /// 录制快捷键期间临时注销全局热键，避免按到已有组合时触发原功能。
    @objc private func shortcutRecordingBegan() {
        for center in hotKeyCenters.values {
            center.unregister()
        }
        Log.app.notice("Hotkeys suspended for shortcut recording")
    }

    @objc private func shortcutRecordingEnded() {
        applyAllHotKeyMappings()
        Log.app.notice("Hotkeys restored after shortcut recording")
    }

    private func handleHotKeyTrigger(_ action: HotKeyAction) {
        switch action {
        case .capture:
            beginSelection()
        case .scrollCapture:
            beginScrollSelection()
        case .pinClickThrough:
            pinnedImageController.toggleClickThroughAll()
        }
    }

    /// 应用新的快捷键设置：注册成功才持久化，失败保留原设置。
    private func applyHotKey(_ mapping: HotKeyMapping, for action: HotKeyAction) -> Bool {
        guard let center = hotKeyCenters[action] else { return false }
        guard center.update(mapping: mapping) else {
            Log.app.error("Failed to rebind \(action.rawValue, privacy: .public) hotkey to \(mapping.displayString, privacy: .public)")
            return false
        }
        settings.setHotKey(mapping, for: action)
        Log.app.notice("Hotkey \(action.rawValue, privacy: .public) -> \(mapping.displayString, privacy: .public)")
        return true
    }

    /// ⌘⇧2：打开所有屏幕的选区覆盖层。
    private func beginSelection() {
        if editorController != nil {
            Log.editor.notice("Hotkey ignored: editor is open")
            return
        }
        if let overlay = selectionOverlay, overlay.isPresented {
            overlay.cancel()
            return
        }
        guard CGPreflightScreenCaptureAccess() else {
            Log.selection.notice("Hotkey ignored: screen recording permission missing")
            onboardingController?.showIfNeeded()
            return
        }

        let overlay = SelectionOverlayController()
        overlay.onCancel = { [weak self] in
            self?.selectionOverlay = nil
            Log.selection.notice("Selection cancelled")
        }
        overlay.onSelect = { [weak self] target, options in
            self?.selectionOverlay = nil
            Task { await self?.capture(target: target, options: options) }
        }
        overlay.present()
        selectionOverlay = overlay
        Log.selection.notice("Selection overlay presented on \(overlay.windows.count, privacy: .public) screen(s)")
    }

    /// ⌘⇧7：框选一块可滚动区域，自动滚动并拼接成长图。
    private func beginScrollSelection() {
        if editorController != nil || scrollCaptureController != nil || isSelectingScrollRegion {
            Log.scroll.notice("Scroll capture ignored: another capture UI is active")
            return
        }
        guard CGPreflightScreenCaptureAccess() else {
            onboardingController?.showIfNeeded()
            return
        }

        isSelectingScrollRegion = true
        let overlay = SelectionOverlayController()
        overlay.onCancel = { [weak self] in
            self?.selectionOverlay = nil
            self?.isSelectingScrollRegion = false
            Log.scroll.notice("Scroll region selection cancelled")
        }
        overlay.onSelect = { [weak self] target, _ in
            self?.selectionOverlay = nil
            self?.isSelectingScrollRegion = false
            self?.handleScrollSelection(target)
        }
        overlay.present()
        selectionOverlay = overlay
        Log.scroll.notice("Scroll region selection presented")
    }

    private func handleScrollSelection(_ target: SelectionTarget) {
        let mainHeight = ScreenCaptureService.mainScreenHeight()
        let screenRect: CGRect
        switch target {
        case .region(let rect):
            screenRect = rect
        case .window(let windowID):
            let windows = WindowIndex.loadCurrent()
            guard let info = windows.windows.first(where: { $0.windowID == windowID }) else {
                presentCaptureError(ScrollCaptureFailure.noScrollableContent)
                return
            }
            screenRect = WindowIndex.screenRect(fromCGRect: info.bounds, mainScreenHeight: mainHeight)
        case .display:
            presentCaptureError(ScrollCaptureFailure.noScrollableContent)
            return
        }

        guard screenRect.width >= 40, screenRect.height >= 40 else {
            presentCaptureError(ScrollCaptureFailure.noScrollableContent)
            return
        }

        // 找选区中心下方的窗口，拿到要滚动的进程。
        let cgCenter = CGPoint(x: screenRect.midX, y: mainHeight - screenRect.midY)
        guard let window = WindowIndex.loadCurrent().hitTest(at: cgCenter) else {
            presentCaptureError(ScrollCaptureFailure.noScrollableContent)
            return
        }

        startScrollCapture(region: screenRect, target: window, scrollLocation: cgCenter)
    }

    private func startScrollCapture(region: CGRect, target: WindowInfo, scrollLocation: CGPoint) {
        let targetPID = target.ownerPID
        let targetName = NSRunningApplication(processIdentifier: targetPID)?.localizedName ?? "?"
        Log.scroll.notice("Scroll capture start target=\(targetName, privacy: .public) pid=\(targetPID, privacy: .public) region=\(String(describing: region), privacy: .public)")

        // 把目标窗口提到最前：AXRaise 比 NSRunningApplication.activate 更可靠
        // （用户正在别的 App 里操作时，后台 App 的 activate 请求可能被系统忽略）。
        raiseWindow(target, pid: targetPID)

        let overlay = ScrollCaptureOverlay()
        overlay.onStop = { [weak self] in
            self?.scrollCaptureController?.cancel()
        }
        overlay.present(near: region)
        scrollOverlay = overlay

        let captureService = screenCaptureService
        let mainHeight = ScreenCaptureService.mainScreenHeight()
        let controller = ScrollCaptureController(
            frameProvider: { rect in
                let cgRect = WindowIndex.cgRect(fromScreenRect: rect, mainScreenHeight: mainHeight)
                return try await captureService.capture(region: cgRect)
            },
            scrollAction: { points, location in
                ScrollCaptureController.postScroll(points: points, location: location)
            }
        )
        controller.onProgress = { [weak self] frameCount, offset in
            self?.scrollOverlay?.update(frameCount: frameCount, message: offset == nil ? nil : "滚动截图中… 已捕获 \(frameCount) 屏")
        }
        scrollCaptureController = controller

        Task { [weak self] in
            guard let self else { return }
            let result = await controller.run(region: region, targetPID: targetPID, scrollLocation: scrollLocation)
            self.scrollOverlay?.dismiss()
            self.scrollOverlay = nil
            self.scrollCaptureController = nil

            switch result {
            case .success(let image):
                self.finishScrollCapture(image: image, region: region)
            case .failure(.cancelled):
                Log.scroll.notice("Scroll capture cancelled")
            case .failure(let failure):
                Log.scroll.error("Scroll capture failed: \(failure.userMessage, privacy: .public)")
                if failure == .accessibilityPermissionRequired {
                    self.promptForAccessibilityOnce()
                }
                self.presentCaptureError(failure)
            }
        }
    }

    private func finishScrollCapture(image: CGImage, region: CGRect) {
        do {
            try clipboardWriter.write(image)
        } catch {
            Log.scroll.error("Scroll capture clipboard write failed: \(error.localizedDescription, privacy: .public)")
        }

        let historyItem = recordHistory(for: image, source: .region(region))

        // 长图按屏幕可用高度缩放到编辑器面板里。
        let visible = NSScreen.screens.first(where: { $0.frame.intersects(region) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? region
        let maxHeight = visible.height * 0.8
        let scale = min(1, maxHeight / CGFloat(image.height))
        let displaySize = CGSize(
            width: CGFloat(image.width) * scale,
            height: CGFloat(image.height) * scale
        )
        let origin = CGPoint(
            x: visible.midX - displaySize.width / 2,
            y: visible.midY - displaySize.height / 2
        )
        presentEditor(image: image, screenFrame: CGRect(origin: origin, size: displaySize), historyItemID: historyItem?.id)
        Log.scroll.notice("Scroll capture finished: \(image.width, privacy: .public)x\(image.height, privacy: .public) px")
    }

    /// 按选区目标截取，成功则写剪贴板与历史，然后进入编辑器。
    private func capture(target: SelectionTarget, options: CaptureOptions) async {
        guard !isCapturing else {
            Log.capture.notice("Capture already in progress; ignoring selection")
            return
        }
        isCapturing = true
        defer { isCapturing = false }

        // 覆盖层已关闭，等一帧让屏幕恢复原状。
        try? await Task.sleep(nanoseconds: 60_000_000)

        do {
            let mainHeight = ScreenCaptureService.mainScreenHeight()
            let image: CGImage
            let source: HistorySource
            let screenFrame: CGRect

            switch target {
            case .region(let screenRect):
                let cgRect = WindowIndex.cgRect(fromScreenRect: screenRect, mainScreenHeight: mainHeight)
                image = try await screenCaptureService.capture(region: cgRect)
                source = .region(screenRect)
                screenFrame = screenRect
                Log.capture.notice("Captured region \(Int(cgRect.width), privacy: .public)x\(Int(cgRect.height), privacy: .public) pt")
            case .window(let windowID):
                image = try await screenCaptureService.capture(windowID: windowID, options: options)
                source = .window(windowID)
                let windows = WindowIndex.loadCurrent()
                if let info = windows.windows.first(where: { $0.windowID == windowID }) {
                    screenFrame = WindowIndex.screenRect(fromCGRect: info.bounds, mainScreenHeight: mainHeight)
                } else {
                    screenFrame = NSScreen.main?.visibleFrame ?? .zero
                }
                Log.capture.notice("Captured window \(windowID, privacy: .public)")
            case .display(let displayID):
                image = try await screenCaptureService.capture(CaptureRequest(displayID: displayID))
                source = .display(displayID)
                screenFrame = NSScreen.screens.first(where: { $0.displayID == displayID })?.frame
                    ?? NSScreen.main?.frame
                    ?? .zero
                Log.capture.notice("Captured display \(displayID, privacy: .public)")
            }

            try clipboardWriter.write(image)
            let historyItem = recordHistory(for: image, source: source)
            Log.capture.notice("Clipboard updated: \(image.width, privacy: .public)x\(image.height, privacy: .public) px")

            presentEditor(image: image, screenFrame: screenFrame, historyItemID: historyItem?.id)
        } catch {
            Log.capture.error("Capture failed: \(error.localizedDescription, privacy: .public)")
            presentCaptureError(error)
        }
    }

    // MARK: - 编辑器

    private func presentEditor(image: CGImage, screenFrame: CGRect, historyItemID: UUID?) {
        let session = EditorSession(sourceImage: image)
        let controller = EditorController(session: session, selectionFrame: screenFrame)

        controller.onFinish = { [weak self] annotated in
            self?.editorController = nil
            self?.publishAnnotated(annotated, historyItemID: historyItemID, saveToFile: false)
        }
        controller.onSave = { [weak self] annotated in
            self?.editorController = nil
            self?.publishAnnotated(annotated, historyItemID: historyItemID, saveToFile: true)
        }
        controller.onCancel = { [weak self] in
            self?.editorController = nil
            Log.editor.notice("Editor cancelled; original stays in clipboard and history")
        }
        controller.onPin = { [weak self] image in
            guard let self else { return }
            let near = self.editorController?.panel?.frame
            self.pinnedImageController.pin(image: image, near: near)
        }

        editorController = controller
        controller.present()
    }

    /// Enter / ⌘C：复制标注版并替换历史；⌘S：另外写文件。
    private func publishAnnotated(_ image: CGImage, historyItemID: UUID?, saveToFile: Bool) {
        do {
            try clipboardWriter.write(image)
        } catch {
            Log.editor.error("Clipboard write failed: \(error.localizedDescription, privacy: .public)")
        }

        if let historyItemID {
            do {
                try historyStore.replaceWithAnnotated(id: historyItemID, image: image)
            } catch {
                Log.history.error("Replace annotated failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        if saveToFile {
            do {
                let exporter = FileExporter(
                    directory: settings.saveDirectory,
                    format: settings.imageFormat,
                    jpegQuality: settings.jpegQuality
                )
                let url = try exporter.save(image)
                Log.editor.notice("Saved annotated image to \(url.path, privacy: .public)")
                menuBarController?.flashSaved()
            } catch {
                Log.editor.error("Save failed: \(error.localizedDescription, privacy: .public)")
                presentCaptureError(error)
            }
        } else {
            menuBarController?.flashSaved()
        }
    }

    /// 把历史里的一条截图贴到屏幕。
    private func pinHistoryItem(_ item: HistoryItem) {
        guard let image = historyStore.loadImage(for: item) else {
            presentCaptureError(CaptureError.captureFailed)
            return
        }
        pinnedImageController.pin(image: image, near: historyWindowController?.window?.frame)
    }

    /// 打开历史窗口（单例，重复点击前置）。
    private func openHistoryWindow() {
        if let window = historyWindowController {
            window.present()
            return
        }
        let controller = HistoryWindowController(store: historyStore)
        controller.onPin = { [weak self] item in
            self?.pinHistoryItem(item)
        }
        historyWindowController = controller
        controller.present()
    }

    /// 把目标 App 的指定窗口提到最前（AXRaise），并尽力激活 App。
    private func raiseWindow(_ target: WindowInfo, pid: pid_t) {
        _ = NSRunningApplication(processIdentifier: pid)?.activate(options: [.activateAllWindows])

        let axApp = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let axWindows = windowsRef as? [AXUIElement] {
            for axWindow in axWindows {
                guard let position = axPosition(of: axWindow), let size = axSize(of: axWindow) else { continue }
                let axFrame = CGRect(origin: position, size: size)
                if abs(axFrame.minX - target.bounds.minX) < 4,
                   abs(axFrame.minY - target.bounds.minY) < 4,
                   abs(axFrame.width - target.bounds.width) < 8,
                   abs(axFrame.height - target.bounds.height) < 8 {
                    let status = AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                    Log.scroll.debug("Scroll AXRaise status=\(status.rawValue, privacy: .public)")
                    break
                }
            }
        }
        // 等待目标 App 真正成为前台，否则第一批滚动事件可能被吞掉。
        let deadline = Date().addingTimeInterval(1.2)
        while Date() < deadline {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid { break }
            usleep(50_000)
        }
        let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil"
        Log.scroll.debug("Scroll frontmost=\(front, privacy: .public)")
    }

    private func axPosition(of element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success,
              let value else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func axSize(of element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success,
              let value else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    // MARK: - 历史与错误

    /// 滚动截图首次失败在权限上时，弹出系统授权提示（只提示一次，之后由用户手动去设置）。
    private func promptForAccessibilityOnce() {
        guard !UserDefaults.standard.bool(forKey: "cap.accessibilityPrompted") else { return }
        UserDefaults.standard.set(true, forKey: "cap.accessibilityPrompted")
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// 截图进剪贴板后写入历史；历史失败不应让已成功的截图变成失败。
    private func recordHistory(for image: CGImage, source: HistorySource) -> HistoryItem? {
        do {
            let item = try historyStore.append(image, source: source)
            Log.history.notice("Inserted history item \(item.id.uuidString, privacy: .public) (\(image.width, privacy: .public)x\(image.height, privacy: .public) px)")
            return item
        } catch {
            Log.history.error("Failed to insert history item: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func presentCaptureError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "操作失败"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        NSApp.activate()
        alert.runModal()
    }
}
