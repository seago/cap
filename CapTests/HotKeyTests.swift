import Carbon.HIToolbox
import Testing
@testable import Cap

@Test func defaultMappingMatchesCommandShift2() {
    let mapping = HotKeyMapping.commandShift2
    #expect(mapping.keyCode == UInt32(kVK_ANSI_2))
    #expect(mapping.modifiers & UInt32(cmdKey) != 0)
    #expect(mapping.modifiers & UInt32(shiftKey) != 0)
    #expect(mapping.displayString == "⌘⇧2")
}

@Test @MainActor func registerAndUnregisterIsIdempotent() {
    let center = HotKeyCenter()
    let mapping = HotKeyMapping(
        keyCode: UInt32(kVK_ANSI_9),
        modifiers: UInt32(cmdKey | shiftKey),
        displayString: "⌘⇧9"
    )

    #expect(center.register(mapping))
    #expect(center.register(mapping))
    center.unregister()
    center.unregister()
}
