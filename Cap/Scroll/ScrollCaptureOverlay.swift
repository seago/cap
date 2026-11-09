import AppKit

/// 滚动截图的悬浮提示窗：显示进度、可点击结束、Esc 取消。
@MainActor
final class ScrollCaptureOverlay {
    private var window: NSPanel?
    private var label: NSTextField?
    private var keyMonitor: Any?
    private var globalKeyMonitor: Any?

    var onStop: (() -> Void)?

    var isPresented: Bool { window != nil }

    func present(near region: CGRect) {
        guard window == nil else { return }

        let label = NSTextField(labelWithString: String(localized: "滚动截图中…"))
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor

        let icon = NSImageView(image: NSImage(systemSymbolName: "arrow.down.doc", accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = .labelColor

        let stopButton = NSButton(title: String(localized: "结束（Esc）"), target: self, action: #selector(stopTapped))
        stopButton.bezelStyle = .rounded
        stopButton.controlSize = .small

        let content = NSStackView(views: [icon, label, stopButton])
        content.orientation = .horizontal
        content.spacing = 10
        content.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        content.layer?.cornerRadius = 10

        let fitting = content.fittingSize
        let window = NSPanel(
            contentRect: CGRect(origin: .zero, size: fitting),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // 不能出现在自己的截图里。
        window.sharingType = .none
        window.contentView = content

        let screen = NSScreen.screens.first(where: { $0.frame.intersects(region) })?.frame
            ?? NSScreen.main?.frame
            ?? region
        let origin = CGPoint(
            x: min(max(region.minX, screen.minX), screen.maxX - fitting.width),
            y: max(screen.minY + 12, region.minY - fitting.height - 12)
        )
        window.setFrame(CGRect(origin: origin, size: fitting), display: false)
        window.orderFront(nil)

        self.window = window
        self.label = label

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            MainActor.assumeIsolated {
                self?.onStop?()
            }
            return nil
        }
        // 截图过程中目标 App 是前台，本地 monitor 收不到 Esc；用全局 monitor（需要辅助功能权限）。
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor in
                self?.onStop?()
            }
        }
    }

    func update(frameCount: Int, message: String? = nil) {
        if let message {
            label?.stringValue = message
        } else {
            label?.stringValue = String(localized: "滚动截图中… 已捕获 \(frameCount) 屏")
        }
    }

    func dismiss() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
        window?.orderOut(nil)
        window = nil
        label = nil
    }

    @objc private func stopTapped() {
        onStop?()
    }
}
