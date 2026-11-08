import AppKit
import CoreGraphics
import Testing
@testable import Cap

@MainActor
@Test func commitDeliversTextAndPixelOrigin() {
    let controller = TextEditingController()
    var received: (String, CGPoint, CGFloat)?
    controller.onCommit = { received = ($0, $1, $2) }

    let canvas = NSView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    controller.begin(
        in: canvas,
        atViewPoint: CGPoint(x: 10, y: 20),
        imagePoint: CGPoint(x: 40, y: 80),
        fontSize: 24,
        color: .systemRed
    )
    #expect(controller.isEditing)
    controller.textField?.stringValue = "你好 Cap"
    controller.commit()

    #expect(received?.0 == "你好 Cap")
    #expect(received?.1 == CGPoint(x: 40, y: 80))
    #expect(received?.2 == 24)
    #expect(controller.isEditing == false)
    #expect(canvas.subviews.isEmpty)
}

@MainActor
@Test func cancelDoesNotCommit() {
    let controller = TextEditingController()
    var committed = false
    var cancelled = false
    controller.onCommit = { _, _, _ in committed = true }
    controller.onCancel = { cancelled = true }

    let canvas = NSView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    controller.begin(in: canvas, atViewPoint: .zero, imagePoint: .zero, fontSize: 20, color: .systemRed)
    controller.textField?.stringValue = "不要"
    controller.cancel()

    #expect(committed == false)
    #expect(cancelled)
    #expect(canvas.subviews.isEmpty)
}

@MainActor
@Test func emptyTextDoesNotCreateAnnotation() {
    let controller = TextEditingController()
    var committed = false
    controller.onCommit = { _, _, _ in committed = true }

    let canvas = NSView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    controller.begin(in: canvas, atViewPoint: .zero, imagePoint: .zero, fontSize: 20, color: .systemRed)
    controller.textField?.stringValue = "   \n "
    controller.commit()

    #expect(committed == false)
    #expect(canvas.subviews.isEmpty)
}

@MainActor
@Test func textAnnotationGoesIntoSession() {
    let context = CGContext(
        data: nil, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let session = EditorSession(sourceImage: context.makeImage()!)
    session.add(.text("标注", origin: CGPoint(x: 5, y: 6), fontSize: 18))

    #expect(session.annotations.count == 1)
    guard case .text(let text, let origin, let fontSize) = session.annotations[0].kind else {
        Issue.record("expected text annotation")
        return
    }
    #expect(text == "标注")
    #expect(origin == CGPoint(x: 5, y: 6))
    #expect(fontSize == 18)
}
