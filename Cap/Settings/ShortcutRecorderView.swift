import AppKit
import SwiftUI

extension Notification.Name {
    /// 开始/结束录制快捷键：期间需要临时注销全局热键，否则按到已有组合会触发原功能。
    static let shortcutRecordingBegan = Notification.Name("CapShortcutRecordingBegan")
    static let shortcutRecordingEnded = Notification.Name("CapShortcutRecordingEnded")
}

/// popover 里的快捷键录制控件：点一下进入录制，按下新组合生效。
/// ⌫ 恢复默认，Esc 取消。
struct ShortcutRecorder: NSViewRepresentable {
    let mapping: HotKeyMapping
    /// nil 表示恢复默认。
    let onRecord: (HotKeyMapping?) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton(mapping: mapping)
        button.onRecord = onRecord
        return button
    }

    func updateNSView(_ nsView: ShortcutRecorderButton, context: Context) {
        nsView.update(mapping: mapping)
        nsView.onRecord = onRecord
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ShortcutRecorderButton, context: Context) -> CGSize? {
        CGSize(width: 132, height: 24)
    }
}

final class ShortcutRecorderButton: NSButton {
    private(set) var mapping: HotKeyMapping
    var onRecord: ((HotKeyMapping?) -> Void)?

    private var isRecording = false

    init(mapping: HotKeyMapping) {
        self.mapping = mapping
        super.init(frame: NSRect(x: 0, y: 0, width: 132, height: 24))
        bezelStyle = .rounded
        controlSize = .small
        font = .systemFont(ofSize: 11)
        target = self
        action = #selector(startRecording)
        updateTitle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    func update(mapping: HotKeyMapping) {
        guard !isRecording else { return }
        self.mapping = mapping
        updateTitle()
    }

    override func becomeFirstResponder() -> Bool {
        true
    }

    @objc private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        title = "按下快捷键…"
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKey()
        window?.makeFirstResponder(self)
        NotificationCenter.default.post(name: .shortcutRecordingBegan, object: nil)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        switch event.keyCode {
        case 53: // Esc
            finish(nil, cancelled: true)
        case 51, 117: // ⌫ / ⌦ 恢复默认
            finish(nil, cancelled: false)
        default:
            guard let newMapping = HotKeyMapping.from(event: event) else {
                NSSound.beep()
                return
            }
            finish(newMapping, cancelled: false)
        }
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            finish(nil, cancelled: true)
        }
        return true
    }

    private func finish(_ newMapping: HotKeyMapping?, cancelled: Bool) {
        isRecording = false
        updateTitle()
        if !cancelled {
            onRecord?(newMapping)
        }
        NotificationCenter.default.post(name: .shortcutRecordingEnded, object: nil)
    }

    private func updateTitle() {
        title = isRecording ? "按下快捷键…" : mapping.displayString
        toolTip = "点击后按下新快捷键；⌫ 恢复默认，Esc 取消"
    }
}
