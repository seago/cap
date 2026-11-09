import AppKit
import Carbon.HIToolbox

struct HotKeyMapping: Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32
    let displayString: String

    static let commandShift2 = HotKeyMapping(
        keyCode: UInt32(kVK_ANSI_2),
        modifiers: UInt32(cmdKey | shiftKey),
        displayString: "⌘⇧2"
    )

    /// 贴图钉屏：切换所有贴图的点击穿透（穿透后只能靠这个热键恢复）。
    static let optionCommandP = HotKeyMapping(
        keyCode: UInt32(kVK_ANSI_P),
        modifiers: UInt32(cmdKey | optionKey),
        displayString: "⌥⌘P"
    )

    /// 滚动长截图（v1.1）。避开系统保留的 ⌘⇧3/4/5/6（截图与 Touch Bar 截图）。
    static let commandShift7 = HotKeyMapping(
        keyCode: UInt32(kVK_ANSI_7),
        modifiers: UInt32(cmdKey | shiftKey),
        displayString: "⌘⇧7"
    )
}

@MainActor
final class HotKeyCenter {
    private static let signature: OSType = 0x43415031 // 'CAP1'

    fileprivate let identifier: UInt32

    var onTrigger: (() -> Void)?

    init(identifier: UInt32 = 1) {
        self.identifier = identifier
    }

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var isRegistered = false

    @discardableResult
    func register(_ mapping: HotKeyMapping = .commandShift2) -> Bool {
        guard !isRegistered else { return true }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            capHotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard handlerStatus == noErr else {
            Log.app.error("InstallEventHandler failed: \(handlerStatus)")
            return false
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: identifier)
        let registerStatus = RegisterEventHotKey(
            mapping.keyCode,
            mapping.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            Log.app.error("RegisterEventHotKey failed: \(registerStatus)")
            if let eventHandlerRef {
                RemoveEventHandler(eventHandlerRef)
                self.eventHandlerRef = nil
            }
            return false
        }

        isRegistered = true
        Log.app.notice("Registered global hotkey \(mapping.displayString, privacy: .public)")
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        isRegistered = false
    }

    fileprivate func handleHotKeyPressed() {
        Log.app.notice("Global hotkey triggered")
        onTrigger?()
    }
}

private func capHotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return noErr }

    var hotKeyID = EventHotKeyID()
    let status = withUnsafeMutablePointer(to: &hotKeyID) { pointer in
        GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            UnsafeMutableRawPointer(pointer)
        )
    }
    guard status == noErr else { return status }

    let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
    // 只处理本实例注册的那个热键（多个 HotKeyCenter 共用同一 Carbon 签名）。
    // 注意：不匹配时必须返回 eventNotHandledErr，否则会吞掉其它实例的热键事件。
    guard hotKeyID.signature == 0x43415031, hotKeyID.id == center.identifier else {
        return OSStatus(eventNotHandledErr)
    }
    MainActor.assumeIsolated {
        center.handleHotKeyPressed()
    }
    return noErr
}
