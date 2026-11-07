import AppKit
import Testing
@testable import Cap

@MainActor
@Test func overlayCreatesOneWindowPerScreen() {
    let controller = SelectionOverlayController()
    controller.present()
    defer { controller.dismiss() }

    #expect(controller.isPresented)
    #expect(controller.windows.count == NSScreen.screens.count)
    #expect(controller.canvasViews.count == NSScreen.screens.count)
}

@MainActor
@Test func overlayWindowsAreExcludedFromCaptureAndJoinAllSpaces() {
    let controller = SelectionOverlayController()
    controller.present()
    defer { controller.dismiss() }

    for window in controller.windows {
        #expect(window.sharingType == .none)
        #expect(window.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(window.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(window.level == .screenSaver)
        #expect(window.isOpaque == false)
    }
}

@MainActor
@Test func dismissRemovesAllWindows() {
    let controller = SelectionOverlayController()
    controller.present()
    controller.dismiss()

    #expect(controller.isPresented == false)
    #expect(controller.windows.isEmpty)
    #expect(controller.canvasViews.isEmpty)
}

@MainActor
@Test func cancelInvokesCallback() {
    let controller = SelectionOverlayController()
    var cancelled = false
    controller.onCancel = { cancelled = true }

    controller.present()
    controller.cancel()

    #expect(cancelled)
    #expect(controller.isPresented == false)
}

@MainActor
@Test func cursorPointOnlySetForVisibleWindows() {
    let controller = SelectionOverlayController()
    controller.present()
    defer { controller.dismiss() }

    controller.setCursorPointForTesting(CGPoint(x: 10, y: 10))
    #expect(controller.canvasViews[0].cursorPoint == CGPoint(x: 10, y: 10))
}

@MainActor
@Test func simulateSelectDismissesAndDeliversTargetAndOptions() {
    let controller = SelectionOverlayController()
    var received: (SelectionTarget, CaptureOptions)?
    controller.onSelect = { target, options in received = (target, options) }

    controller.present()
    controller.simulateSelect(.region(CGRect(x: 0, y: 0, width: 10, height: 10)), options: .windowDefault)

    #expect(controller.isPresented == false)
    #expect(received?.0 == .region(CGRect(x: 0, y: 0, width: 10, height: 10)))
    #expect(received?.1 == .windowDefault)
}

@MainActor
@Test func simulateSelectPassesShadowOption() {
    let controller = SelectionOverlayController()
    var receivedOptions: CaptureOptions?
    controller.onSelect = { _, options in receivedOptions = options }

    controller.present()
    controller.simulateSelect(.window(7), options: .windowWithoutShadow)

    #expect(receivedOptions == .windowWithoutShadow)
}
