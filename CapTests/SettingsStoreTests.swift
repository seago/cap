import Foundation
import Testing
@testable import Cap

@MainActor
private func makeDefaults() -> UserDefaults {
    let suite = "cap.tests.settings.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

@MainActor
@Test func defaultsArePNGAndScreenshotsDirectory() {
    let store = SettingsStore(defaults: makeDefaults())
    #expect(store.imageFormat == .png)
    #expect(store.jpegQuality == 0.85)
    #expect(store.saveDirectory == SettingsStore.defaultDirectory)
    #expect(store.historyLimit == 100)
}

@MainActor
@Test func valuesRoundTrip() {
    let defaults = makeDefaults()
    let store = SettingsStore(defaults: defaults)
    store.imageFormat = .jpeg
    store.jpegQuality = 0.7
    store.saveDirectory = URL(fileURLWithPath: "/tmp/cap-shots", isDirectory: true)

    let reloaded = SettingsStore(defaults: defaults)
    #expect(reloaded.imageFormat == .jpeg)
    #expect(reloaded.jpegQuality == 0.7)
    #expect(reloaded.saveDirectory.path == "/tmp/cap-shots")
}

@MainActor
@Test func emptyDirectoryFallsBackToDefault() {
    let defaults = makeDefaults()
    let store = SettingsStore(defaults: defaults)
    defaults.set("", forKey: SettingsStore.Key.saveDirectory)
    #expect(store.saveDirectory == SettingsStore.defaultDirectory)
}

@MainActor
@Test func invalidFormatFallsBackToPNG() {
    let defaults = makeDefaults()
    defaults.set("heic", forKey: SettingsStore.Key.imageFormat)
    let store = SettingsStore(defaults: defaults)
    #expect(store.imageFormat == .png)
}

@Test func formatExtensionsMatchExport() {
    #expect(ImageFormat.png.fileExtension == "png")
    #expect(ImageFormat.jpeg.fileExtension == "jpg")
}

@MainActor
final class FakeLaunchAtLogin: LaunchAtLoginControlling {
    var isEnabled = false
    private(set) var setCalls: [Bool] = []
    func setEnabled(_ enabled: Bool) throws {
        setCalls.append(enabled)
        isEnabled = enabled
    }
}

@MainActor
@Test func fakeLaunchAtLoginToggles() throws {
    let controller = FakeLaunchAtLogin()
    #expect(controller.isEnabled == false)
    try controller.setEnabled(true)
    #expect(controller.isEnabled)
    #expect(controller.setCalls == [true])
}
