import Testing
@testable import Cap

@MainActor
final class FakePermissionProvider: ScreenRecordingPermissionProviding {
    var preflightResult = false
    var requestResult = false
    private(set) var openSettingsCount = 0
    private(set) var relaunchCount = 0

    func preflight() -> Bool { preflightResult }
    func request() -> Bool { requestResult }
    func openSystemSettings() { openSettingsCount += 1 }
    func relaunch() { relaunchCount += 1 }
}

@Test @MainActor func notDeterminedBeforeAnyRequest() {
    let provider = FakePermissionProvider()
    let model = ScreenRecordingPermissionModel(provider: provider)
    model.refresh()
    #expect(model.access == .notDetermined)
}

@Test @MainActor func grantedAfterSuccessfulRequest() {
    let provider = FakePermissionProvider()
    provider.requestResult = true
    let model = ScreenRecordingPermissionModel(provider: provider)
    model.request()
    #expect(model.access == .granted)
}

@Test @MainActor func deniedAfterRejectedRequest() {
    let provider = FakePermissionProvider()
    provider.requestResult = false
    let model = ScreenRecordingPermissionModel(provider: provider)
    model.request()
    #expect(model.access == .denied)
}

@Test @MainActor func recheckAfterSettingsSuggestsRestart() {
    let provider = FakePermissionProvider()
    let model = ScreenRecordingPermissionModel(provider: provider)
    model.openSystemSettings()
    model.recheck()
    #expect(model.access == .restartRequired)
    #expect(provider.openSettingsCount == 1)
}

@Test @MainActor func refreshDetectsGranted() {
    let provider = FakePermissionProvider()
    provider.preflightResult = true
    let model = ScreenRecordingPermissionModel(provider: provider)
    model.refresh()
    #expect(model.access == .granted)
}

@Test @MainActor func restartDelegatesToProvider() {
    let provider = FakePermissionProvider()
    let model = ScreenRecordingPermissionModel(provider: provider)
    model.restartApp()
    #expect(provider.relaunchCount == 1)
}

@Test @MainActor func relaunchRequestsNewApplicationInstance() {
    let configuration = ScreenRecordingRelaunch.makeConfiguration()
    #expect(configuration.createsNewApplicationInstance)
    #expect(configuration.activates)
}
