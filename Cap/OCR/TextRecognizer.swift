import CoreGraphics
import Foundation
import Vision

/// 识别出的一行文字。
struct OCRLine: Equatable, Sendable {
    let text: String
    let confidence: Float
    /// Vision 归一化坐标（原点左下）。
    let boundingBox: CGRect
}

/// 一次 OCR 的结果。
struct OCRResult: Equatable, Sendable {
    let lines: [OCRLine]

    var text: String {
        lines.map(\.text).joined(separator: "\n")
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum OCRError: LocalizedError, Equatable {
    case requestFailed(String)
    case imageUnavailable

    var errorDescription: String? {
        switch self {
        case .requestFailed(let message):
            return "文字识别失败：\(message)"
        case .imageUnavailable:
            return "图片无法读取，无法识别文字。"
        }
    }
}

/// 可替换的文字识别接口（测试注入假实现）。
protocol TextRecognizing: Sendable {
    func recognizeText(in image: CGImage) async throws -> OCRResult
}

/// 本地 Vision OCR：中英混排、离线、不联网。
struct VisionTextRecognizer: TextRecognizing {
    var languages: [String] = ["zh-Hans", "zh-Hant", "en-US"]
    var recognitionLevel: VNRequestTextRecognitionLevel = .accurate

    func recognizeText(in image: CGImage) async throws -> OCRResult {
        let languages = self.languages
        let recognitionLevel = self.recognitionLevel
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = recognitionLevel
                request.usesLanguageCorrection = true
                request.recognitionLanguages = languages

                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: OCRError.requestFailed(error.localizedDescription))
                    return
                }

                let observations = (request.results ?? []).compactMap { observation -> OCRLine? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return nil }
                    return OCRLine(
                        text: text,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }

                continuation.resume(returning: OCRResult(lines: Self.readingOrder(observations)))
            }
        }
    }

    /// 按阅读顺序排列：先按行（同一水平带的归一行），行内从左到右，行间从上到下。
    static func readingOrder(_ lines: [OCRLine]) -> [OCRLine] {
        // Vision 坐标原点在左下：y 越大越靠上。
        let tolerance: CGFloat = 0.02
        var rows: [[OCRLine]] = []
        for line in lines.sorted(by: { $0.boundingBox.midY > $1.boundingBox.midY }) {
            if var last = rows.last, let reference = last.first,
               abs(reference.boundingBox.midY - line.boundingBox.midY) <= tolerance {
                last.append(line)
                rows[rows.count - 1] = last
            } else {
                rows.append([line])
            }
        }
        return rows.flatMap { row in
            row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        }
    }
}
