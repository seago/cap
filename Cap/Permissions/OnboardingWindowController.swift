import AppKit

@MainActor
final class OnboardingWindowController: NSWindowController {
    private let model: ScreenRecordingPermissionModel
    private let statusLabel = NSTextField(labelWithString: "")

    init(model: ScreenRecordingPermissionModel = ScreenRecordingPermissionModel()) {
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Cap 需要屏幕录制权限"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showIfNeeded() {
        model.refresh()
        if model.access == .granted {
            markCompleted()
            return
        }
        updateStatus()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildContent() {
        let title = NSTextField(labelWithString: "Cap 需要「屏幕录制」权限")
        title.font = .systemFont(ofSize: 16, weight: .semibold)

        let body = NSTextField(wrappingLabelWithString: "没有这项权限，Cap 无法截取屏幕。请在系统设置 → 隐私与安全性 → 录屏与系统录音中勾选 Cap，然后回到这里点「重新检测」。\n\n截图只在本机处理，不联网、不上传。")
        body.font = .systemFont(ofSize: 12)
        body.textColor = .secondaryLabelColor
        body.preferredMaxLayoutWidth = 416

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.preferredMaxLayoutWidth = 416

        let requestButton = NSButton(title: "请求权限", target: self, action: #selector(requestAccess))
        let settingsButton = NSButton(title: "打开系统设置", target: self, action: #selector(openSettings))
        let recheckButton = NSButton(title: "重新检测", target: self, action: #selector(recheck))
        let restartButton = NSButton(title: "重新启动 Cap", target: self, action: #selector(restart))
        let laterButton = NSButton(title: "稍后", target: self, action: #selector(later))

        let primary = NSStackView(views: [requestButton, settingsButton])
        primary.orientation = .horizontal
        primary.spacing = 8

        let secondary = NSStackView(views: [recheckButton, restartButton, laterButton])
        secondary.orientation = .horizontal
        secondary.spacing = 8

        let buttons = NSStackView(views: [primary, secondary])
        buttons.orientation = .vertical
        buttons.alignment = .leading
        buttons.spacing = 8

        let stack = NSStackView(views: [title, body, statusLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window?.contentView = content
    }

    private func updateStatus() {
        switch model.access {
        case .notDetermined:
            statusLabel.stringValue = "当前状态：尚未请求权限。"
        case .granted:
            statusLabel.stringValue = "当前状态：已授权。"
        case .denied:
            statusLabel.stringValue = "当前状态：权限被拒绝，请在系统设置中打开。"
        case .restartRequired:
            statusLabel.stringValue = "当前状态：如果已在系统设置中授权，请重新启动 Cap。"
        }
    }

    private func markCompleted() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    @objc private func requestAccess() {
        model.request()
        updateStatus()
        if model.access == .granted {
            markCompleted()
        }
    }

    @objc private func openSettings() {
        model.openSystemSettings()
        updateStatus()
    }

    @objc private func recheck() {
        model.recheck()
        updateStatus()
        if model.access == .granted {
            markCompleted()
            window?.close()
        }
    }

    @objc private func restart() {
        model.restartApp()
    }

    @objc private func later() {
        markCompleted()
        window?.close()
    }
}
