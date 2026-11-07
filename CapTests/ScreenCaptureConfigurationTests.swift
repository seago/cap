import CoreGraphics
import ScreenCaptureKit
import Testing
@testable import Cap

@Test @MainActor func displayConfigurationDisablesCursor() {
    let configuration = ScreenCaptureService.displayConfiguration(width: 1920, height: 1200)
    #expect(configuration.width == 1920)
    #expect(configuration.height == 1200)
    #expect(configuration.showsCursor == false)
}

@Test @MainActor func windowConfigurationKeepsShadowByDefault() {
    let configuration = ScreenCaptureService.windowConfiguration(
        width: 800,
        height: 600,
        options: .windowDefault
    )
    #expect(configuration.width == 800)
    #expect(configuration.height == 600)
    #expect(configuration.ignoreShadowsSingleWindow == false)
    #expect(configuration.showsCursor == false)
}

@Test @MainActor func windowConfigurationDropsShadowWhenRequested() {
    let configuration = ScreenCaptureService.windowConfiguration(
        width: 800,
        height: 600,
        options: .windowWithoutShadow
    )
    #expect(configuration.ignoreShadowsSingleWindow == true)
}

@Test @MainActor func regionSmallerThanOnePointIsInvalid() async {
    let service = ScreenCaptureService()
    await #expect(throws: CaptureError.invalidRegion) {
        try await service.capture(region: CGRect(x: 10, y: 10, width: 0, height: 0))
    }
}
