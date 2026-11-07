import AppKit
import CoreGraphics

@MainActor
protocol PasteboardWriting: AnyObject {
    func clear()
    func write(_ data: Data, type: NSPasteboard.PasteboardType) -> Bool
}

@MainActor
final class SystemPasteboard: PasteboardWriting {
    private let pasteboard: NSPasteboard

    init(_ pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func clear() {
        pasteboard.clearContents()
    }

    func write(_ data: Data, type: NSPasteboard.PasteboardType) -> Bool {
        pasteboard.setData(data, forType: type)
    }
}

@MainActor
final class ClipboardWriter {
    private let pasteboard: PasteboardWriting

    init(pasteboard: PasteboardWriting = SystemPasteboard()) {
        self.pasteboard = pasteboard
    }

    func write(_ image: CGImage) throws {
        guard let png = ImageEncoder.pngData(from: image) else {
            throw CaptureError.encodingFailed
        }
        guard let tiff = ImageEncoder.tiffData(from: image) else {
            throw CaptureError.encodingFailed
        }

        pasteboard.clear()
        guard pasteboard.write(png, type: .png) else {
            throw CaptureError.clipboardWriteFailed
        }
        guard pasteboard.write(tiff, type: .tiff) else {
            throw CaptureError.clipboardWriteFailed
        }
    }
}
