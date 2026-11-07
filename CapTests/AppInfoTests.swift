import Testing
@testable import Cap

@Test func appInfoMatchesDesignBaseline() {
    #expect(AppInfo.bundleIdentifier == "dev.bruce.cap")
    #expect(AppInfo.version == "0.1.0")
    #expect(AppInfo.displayName == "Cap")
}
