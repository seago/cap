import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import Cap

// MARK: - 合成文字图

private func makeTextImage(_ text: String, fontSize: CGFloat = 56) -> CGImage {
    let size = NSSize(width: 720, height: 160)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
        .foregroundColor: NSColor.black,
    ]
    (text as NSString).draw(at: NSPoint(x: 24, y: 50), withAttributes: attributes)
    image.unlockFocus()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return rep.cgImage!
}

private func makeBlankImage() -> CGImage {
    let context = CGContext(
        data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
    return context.makeImage()!
}

@MainActor
@Test func visionRecognizerFindsChineseAndEnglishText() async throws {
    let recognizer = VisionTextRecognizer()
    let result = try await recognizer.recognizeText(in: makeTextImage("Cap OCR 测试文字"))
    #expect(!result.isEmpty)
    #expect(result.text.contains("Cap"))
    #expect(result.text.contains("OCR"))
    #expect(result.lines.allSatisfy { $0.confidence > 0 })
}

@MainActor
@Test func blankImageReturnsEmptyResult() async throws {
    let recognizer = VisionTextRecognizer()
    let result = try await recognizer.recognizeText(in: makeBlankImage())
    #expect(result.isEmpty)
}

@Test func readingOrderSortsByRowThenColumn() {
    let lines = [
        OCRLine(text: "third", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.05)),
        OCRLine(text: "first", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.2, height: 0.05)),
        OCRLine(text: "second", confidence: 1, boundingBox: CGRect(x: 0.5, y: 0.8, width: 0.2, height: 0.05)),
    ]
    let ordered = VisionTextRecognizer.readingOrder(lines).map(\.text)
    #expect(ordered == ["first", "second", "third"])
}

// MARK: - 兼容性 / 存储

@Test func historyItemWithoutOCRTextDecodes() throws {
    let json = """
    {
      "id": "0B1C2D3E-0000-0000-0000-000000000001",
      "createdAt": 760000000,
      "source": { "type": "unknown" },
      "pixelWidth": 10,
      "pixelHeight": 20,
      "fileName": "0B1C2D3E-0000-0000-0000-000000000001.png",
      "isAnnotated": false
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .deferredToDate
    let item = try decoder.decode(HistoryItem.self, from: Data(json.utf8))
    #expect(item.ocrText == nil)
    #expect(item.thumbFileName == nil)
}

@MainActor
@Test func setOCRTextPersistsToIndex() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("cap-ocr-tests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = HistoryStore(rootURL: root)

    let context = CGContext(
        data: nil, width: 40, height: 30, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let item = try store.append(context.makeImage()!, source: .unknown)

    let updated = try store.setOCRText(id: item.id, text: "识别结果")
    #expect(updated.ocrText == "识别结果")
    #expect(store.items.first?.ocrText == "识别结果")

    let reloaded = HistoryStore(rootURL: root)
    #expect(reloaded.items.first?.ocrText == "识别结果")
}

@MainActor
@Test func setOCRTextUnknownIDThrows() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("cap-ocr-tests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = HistoryStore(rootURL: root)
    #expect(throws: HistoryError.itemNotFound) {
        try store.setOCRText(id: UUID(), text: "x")
    }
}

// MARK: - 注入假识别器（历史窗口依赖它）

@MainActor
@Test func recognizerProtocolIsInjectable() async throws {
    struct FakeRecognizer: TextRecognizing {
        func recognizeText(in image: CGImage) async throws -> OCRResult {
            OCRResult(lines: [OCRLine(text: "来自假识别器", confidence: 1, boundingBox: .zero)])
        }
    }
    let result = try await FakeRecognizer().recognizeText(in: makeBlankImage())
    #expect(result.text == "来自假识别器")
}
