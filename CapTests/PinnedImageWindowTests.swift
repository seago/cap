import AppKit
import Testing
@testable import Cap

@MainActor
@Test func pinnedWindowStaysVisibleAfterAppDeactivation() {
    let window = PinnedImageWindow(frame: CGRect(x: 100, y: 100, width: 200, height: 150))
    // App 失去焦点时 NSPanel 默认会被隐藏；钉屏必须显式恢复（#36 用户反馈）。
    #expect(window.hidesOnDeactivate == false)
    #expect(window.level == .floating)
    #expect(window.collectionBehavior.contains(.canJoinAllSpaces))
    #expect(window.collectionBehavior.contains(.fullScreenAuxiliary))
    #expect(window.sharingType == .none)
    #expect(window.canBecomeKey)
    #expect(!window.canBecomeMain)
}

@MainActor
@Test func clickThroughTogglesMouseEvents() {
    let window = PinnedImageWindow(frame: CGRect(x: 100, y: 100, width: 200, height: 150))
    #expect(window.clickThrough == false)
    #expect(window.ignoresMouseEvents == false)
    window.setClickThrough(true)
    #expect(window.clickThrough == true)
    #expect(window.ignoresMouseEvents == true)
    window.setClickThrough(false)
    #expect(window.ignoresMouseEvents == false)
}
