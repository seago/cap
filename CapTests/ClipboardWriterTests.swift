import AppKit
import CoreGraphics
import Testing
@testable import Cap

@MainActor
final class FakePasteboard: PasteboardWriting {
    private(set) var cleared = false
    private(set) var written: [(type: NSPasteboard.PasteboardType, data: Data)] = []
    var failWrites = false

    func clear() {
        cleared = true
        written.removeAll()
    }

    func write(_ data: Data, type: NSPasteboard.PasteboardType) -> Bool {
        if failWrites { return false }
        written.append((type, data))
        return true
    }
}

private func makeImage(width: Int = 4, height: Int = 3) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

@Test @MainActor func writesPNGAndTIFFAndClearsPasteboard() throws {
    let pasteboard = FakePasteboard()
    let writer = ClipboardWriter(pasteboard: pasteboard)

    try writer.write(makeImage())

    #expect(pasteboard.cleared)
    #expect(pasteboard.written.count == 2)
    #expect(Set(pasteboard.written.map(\.type)) == [.png, .tiff])
    #expect(pasteboard.written.allSatisfy { !$0.data.isEmpty })
}

@Test @MainActor func throwsWhenWriteFails() {
    let pasteboard = FakePasteboard()
    pasteboard.failWrites = true
    let writer = ClipboardWriter(pasteboard: pasteboard)

    #expect(throws: CaptureError.clipboardWriteFailed) {
        try writer.write(makeImage())
    }
}
