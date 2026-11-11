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
@Test func valuesRoundTrip() throws {
    let defaults = makeDefaults()
    let store = SettingsStore(defaults: defaults)
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("cap-roundtrip-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    store.imageFormat = .jpeg
    store.jpegQuality = 0.7
    store.saveDirectory = directory

    let reloaded = SettingsStore(defaults: defaults)
    #expect(reloaded.imageFormat == .jpeg)
    #expect(reloaded.jpegQuality == 0.7)
    #expect(reloaded.saveDirectory.standardizedFileURL == directory.standardizedFileURL)
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
    var status: LaunchAtLoginStatus = .disabled
    private(set) var enableCalls = 0
    private(set) var disableCalls = 0
    private(set) var openSettingsCalls = 0

    func enable() throws {
        enableCalls += 1
        status = .enabled
    }

    func disable() throws {
        disableCalls += 1
        status = .disabled
    }

    func openSystemSettings() {
        openSettingsCalls += 1
    }
}

@MainActor
@Test func fakeLaunchAtLoginToggles() throws {
    let controller = FakeLaunchAtLogin()
    #expect(controller.status == .disabled)
    try controller.enable()
    #expect(controller.status == .enabled)
    try controller.disable()
    #expect(controller.status == .disabled)
    #expect(controller.enableCalls == 1)
    #expect(controller.disableCalls == 1)
}

@MainActor
@Test func nonexistentSaveDirectoryFallsBackToDefault() {
    let defaults = makeDefaults()
    let store = SettingsStore(defaults: defaults)
    defaults.set("/Volumes/cap-missing-volume/screenshots", forKey: SettingsStore.Key.saveDirectory)
    #expect(store.saveDirectory == SettingsStore.defaultDirectory)
}

@MainActor
@Test func existingSaveDirectoryIsKept() throws {
    let defaults = makeDefaults()
    let store = SettingsStore(defaults: defaults)
    let temporary = FileManager.default.temporaryDirectory
        .appendingPathComponent("cap-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }

    store.saveDirectory = temporary
    #expect(store.saveDirectory.standardizedFileURL == temporary.standardizedFileURL)
}

@MainActor
@Test func firstLaunchDefaultLaunchAtLoginIsAppliedOnce() {
    let sessionStore = makeDefaults()
    let store = SettingsStore(defaults: sessionStore)
    #expect(store.shouldApplyDefaultLaunchAtLogin)

    store.markDefaultLaunchAtLoginApplied()
    #expect(store.shouldApplyDefaultLaunchAtLogin == false)
}

// MARK: - 沙盒（App Store 版）相关

@MainActor
@Test func fileInsteadOfDirectoryFallsBackToDefault() throws {
    let defaults = makeDefaults()
    let store = SettingsStore(defaults: defaults)
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("cap-file-\(UUID().uuidString)")
    try Data("x".utf8).write(to: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    store.saveDirectory = fileURL
    #expect(store.saveDirectory == SettingsStore.defaultDirectory)
}

@MainActor
@Test func saveDirectoryStoresResolvableBookmark() throws {
    let defaults = makeDefaults()
    let store = SettingsStore(defaults: defaults)
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("cap-bookmark-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    store.saveDirectory = directory
    // 非沙盒环境通常只能拿到普通 bookmark；沙盒下是 security-scoped bookmark。
    let bookmark = try #require(defaults.data(forKey: SettingsStore.Key.saveDirectoryBookmark))
    var stale = false
    let resolved = try URL(
        resolvingBookmarkData: bookmark,
        options: [.withoutUI],
        relativeTo: nil,
        bookmarkDataIsStale: &stale
    )
    #expect(resolved.standardizedFileURL == directory.standardizedFileURL)
}
