import AppKit
import Carbon.HIToolbox

struct HotKeyMapping: Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32
    let displayString: String

    init(keyCode: UInt32, modifiers: UInt32, displayString: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayString = displayString
    }

    /// 由录制结果构造（显示字符串自动生成）。
    init(keyCode: UInt32, modifiers: UInt32) {
        self.init(keyCode: keyCode, modifiers: modifiers, displayString: Self.displayString(keyCode: keyCode, modifiers: modifiers))
    }

    /// Carbon 修饰键 → 展示字符（⌘⌥⌃⇧ 顺序）。
    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        var result = ""
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        return result + keyName(for: keyCode)
    }

    static func keyName(for keyCode: UInt32) -> String {
        keyNames[Int(keyCode)] ?? "Key\(keyCode)"
    }

    /// NSEvent → Carbon 修饰键；不含 ⌘/⌥/⌃ 的组合不接受（避免占用普通输入）。
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        return modifiers
    }

    static func from(event: NSEvent) -> HotKeyMapping? {
        let modifiers = carbonModifiers(from: event.modifierFlags)
        guard modifiers & UInt32(cmdKey | optionKey | controlKey) != 0 else { return nil }
        return HotKeyMapping(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    }

    private static let keyNames: [Int: String] = {
        var names: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
            kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
            kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
            kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
            kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
            kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
            kVK_ANSI_8: "8", kVK_ANSI_9: "9",
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "Esc",
            kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
            kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
            kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        names[Int(kVK_ANSI_Equal)] = "="
        names[Int(kVK_ANSI_Minus)] = "-"
        names[Int(kVK_ANSI_LeftBracket)] = "["
        names[Int(kVK_ANSI_RightBracket)] = "]"
        names[Int(kVK_ANSI_Backslash)] = "\\"
        names[Int(kVK_ANSI_Semicolon)] = ";"
        names[Int(kVK_ANSI_Quote)] = "'"
        names[Int(kVK_ANSI_Comma)] = ","
        names[Int(kVK_ANSI_Period)] = "."
        names[Int(kVK_ANSI_Slash)] = "/"
        names[Int(kVK_ANSI_Grave)] = "`"
        return names
    }()

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

/// 可自定义的全局快捷键动作。
enum HotKeyAction: String, CaseIterable, Sendable {
    case capture
    case scrollCapture
    case pinClickThrough

    var title: String {
        switch self {
        case .capture: return "截图"
        case .scrollCapture: return "滚动截图"
        case .pinClickThrough: return "贴图穿透切换"
        }
    }

    var defaultMapping: HotKeyMapping {
        switch self {
        case .capture: return .commandShift2
        case .scrollCapture: return .commandShift7
        case .pinClickThrough: return .optionCommandP
        }
    }

    var identifier: UInt32 {
        switch self {
        case .capture: return 1
        case .scrollCapture: return 2
        case .pinClickThrough: return 3
        }
    }
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
    private(set) var currentMapping: HotKeyMapping?
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
        currentMapping = mapping
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
        currentMapping = nil
    }

    /// 换绑快捷键：先注销旧组合，再注册新组合；失败时尝试恢复旧组合。
    @discardableResult
    func update(mapping newMapping: HotKeyMapping) -> Bool {
        if isRegistered, currentMapping == newMapping { return true }
        let previous = currentMapping
        unregister()
        if register(newMapping) {
            return true
        }
        if let previous {
            _ = register(previous)
        }
        return false
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
