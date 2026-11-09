import AppKit
import Carbon.HIToolbox
import Testing
@testable import Cap

@MainActor
private func makeDefaults() -> UserDefaults {
    let suite = "cap.tests.hotkeys.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

private func event(
    keyCode: UInt16,
    modifiers: NSEvent.ModifierFlags,
    characters: String = "x"
) -> NSEvent {
    NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: modifiers,
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: characters,
        charactersIgnoringModifiers: characters,
        isARepeat: false,
        keyCode: keyCode
    )!
}

@MainActor
@Test func defaultHotKeysAreTheShippedDefaults() {
    let store = SettingsStore(defaults: makeDefaults())
    #expect(store.hotKey(for: .capture) == .commandShift2)
    #expect(store.hotKey(for: .scrollCapture) == .commandShift7)
    #expect(store.hotKey(for: .pinClickThrough) == .optionCommandP)
}

@MainActor
@Test func hotKeyPersistsAndReloads() {
    let defaults = makeDefaults()
    let store = SettingsStore(defaults: defaults)
    let custom = HotKeyMapping(keyCode: UInt32(kVK_ANSI_J), modifiers: UInt32(cmdKey | optionKey))
    store.setHotKey(custom, for: .capture)

    let reloaded = SettingsStore(defaults: defaults)
    #expect(reloaded.hotKey(for: .capture) == custom)
    #expect(reloaded.hotKey(for: .capture).displayString == "⌘⌥J")
    // 其它动作不受影响
    #expect(reloaded.hotKey(for: .scrollCapture) == .commandShift7)
}

@MainActor
@Test func resetRestoresDefault() {
    let defaults = makeDefaults()
    let store = SettingsStore(defaults: defaults)
    store.setHotKey(HotKeyMapping(keyCode: UInt32(kVK_ANSI_J), modifiers: UInt32(cmdKey)), for: .capture)
    store.resetHotKey(for: .capture)
    #expect(store.hotKey(for: .capture) == .commandShift2)
}

@MainActor
@Test func conflictDetectionFindsOtherAction() {
    let store = SettingsStore(defaults: makeDefaults())
    let newMapping = HotKeyMapping(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey | shiftKey))
    #expect(store.hotKeyConflict(newMapping, excluding: .capture) == nil)

    store.setHotKey(newMapping, for: .scrollCapture)
    #expect(store.hotKeyConflict(newMapping, excluding: .capture) == .scrollCapture)
}

@Test func displayStringFormatsModifiersAndKeys() {
    #expect(HotKeyMapping.displayString(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(cmdKey | shiftKey)) == "⌘⇧2")
    #expect(HotKeyMapping.displayString(keyCode: UInt32(kVK_ANSI_7), modifiers: UInt32(cmdKey | shiftKey)) == "⌘⇧7")
    #expect(HotKeyMapping.displayString(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(cmdKey | optionKey)) == "⌘⌥P")
    #expect(HotKeyMapping.displayString(keyCode: UInt32(kVK_ANSI_1), modifiers: UInt32(controlKey | shiftKey)) == "⌃⇧1")
    #expect(HotKeyMapping.displayString(keyCode: UInt32(kVK_F5), modifiers: UInt32(cmdKey)) == "⌘F5")
}

@Test func mappingFromEventMatchesDefaults() {
    let mapping = HotKeyMapping.from(event: event(keyCode: 19, modifiers: [.command, .shift], characters: "2"))
    #expect(mapping == .commandShift2)
}

@Test func bareOrShiftOnlyKeysAreRejected() {
    #expect(HotKeyMapping.from(event: event(keyCode: 19, modifiers: [])) == nil)
    #expect(HotKeyMapping.from(event: event(keyCode: 19, modifiers: [.shift])) == nil)
    // 有 ⌘/⌥/⌃ 才接受
    #expect(HotKeyMapping.from(event: event(keyCode: 19, modifiers: [.option])) != nil)
}

@MainActor
@Test func allHotKeysReturnsEveryAction() {
    let store = SettingsStore(defaults: makeDefaults())
    let all = store.allHotKeys()
    #expect(all.count == HotKeyAction.allCases.count)
    #expect(all[.pinClickThrough] == .optionCommandP)
}
