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
}

@MainActor
final class HotKeyCenter {
    private static let signature: OSType = 0x43415031 // 'CAP1'
    private static let identifier: UInt32 = 1

    var onTrigger: (() -> Void)?

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

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.identifier)
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
    guard hotKeyID.signature == 0x43415031, hotKeyID.id == 1 else { return noErr }

    let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated {
        center.handleHotKeyPressed()
    }
    return noErr
}
