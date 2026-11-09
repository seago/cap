import Accelerate
import CoreGraphics
import Foundation

/// 滚动截图拼接结果。
struct StitchedImage {
    /// 拼接后的长图。
    let image: CGImage
    /// 真正参与拼接的帧数（含第一帧）。遇到不可信的重叠会提前结束，因此可能小于输入帧数。
    let frameCount: Int
}

/// 滚动截图拼接失败原因。
enum ScrollStitchError: Error, Equatable {
    /// 没有任何输入帧。
    case emptyFrames
    /// 第一对帧之间找不到可信的重叠：还拼不出任何东西。
    case noOverlap
    /// `CGImage` 解码成像素失败（也用于帧尺寸不一致）。
    case decodeFailed
}

/// 把连续向下滚动的截图帧拼成一张长图。
///
/// 帧按从早到晚排列。后一帧相对前一帧向上滚动了 `offset` 像素，因此
/// 「后一帧的第 y 行」应与「前一帧的第 y + offset 行」逐像素相同。
///
/// 算法分四步，目标是既有逐像素精度又远快于朴素的二维全分辨率搜索：
///
/// 1. 用 `CGContext` 以 1:1、无插值地把每帧解码成 RGBA8 像素。
/// 2. 先判断两帧是否基本相同：是则偏移为 0（页面已经滚到底或没滚动）。
/// 3. 用 Accelerate/vDSP 计算每帧每行的 5 个统计特征（RGB 行均值、行亮度标准差、
///    行内水平梯度）。真实偏移处这些特征的差严格为 0，所以「一维滑动比较行特征」
///    就能以 O(搜索距离 × 高度) 的代价圈出极少数候选偏移，避免逐像素二维搜索。
/// 4. 对候选偏移做稀疏二维采样排序，再对最可能的少量偏移做全分辨率逐通道平均绝对差
///    验证：只有平均差 ≤ `overlapTolerance` 且明显优于其它偏移时才接受。无法可靠判断时
///    返回 nil / 提前结束，宁可少拼也不拼出错位的长图。
struct ScrollStitcher {
    /// 相邻两帧至少要有这么多像素的重叠才算可信。
    var minimumOverlap: Int = 80
    /// 相邻两帧之间内容最多可能跳动的像素数（搜索上限）。
    var maximumSearchDistance: Int = 1200
    /// 重叠区域逐通道平均绝对差阈值（0...255）。
    var overlapTolerance: Double = 12.0

    /// 行特征一维匹配保留的候选偏移数。
    private static let profileCandidateLimit = 24
    /// 对多少个候选偏移做全分辨率验证。
    private static let verificationCandidateLimit = 3
    /// 两个不同偏移的平均差相差小于该值时视为有歧义，放弃拼接。
    private static let ambiguityMargin = 0.5
    /// 每行的特征数量：meanR、meanG、meanB、亮度标准差、行内水平梯度。
    private static let featureCount = 5
    /// 稀疏二维校验最多采样多少行 / 列。
    private static let sampledRowLimit = 80
    private static let sampledColumnLimit = 320

    /// 拼接连续滚动的帧，返回长图。
    ///
    /// - 帧尺寸必须一致，否则抛 `.decodeFailed`。
    /// - 第一对帧找不到可信重叠时抛 `.noOverlap`（此时没有可保留的拼接内容）。
    /// - 之后任意一对帧无法拼接时停止追加，返回已经拼好的部分，不丢弃已有内容。
    func stitch(frames: [CGImage]) throws -> StitchedImage {
        guard let firstFrame = frames.first else {
            throw ScrollStitchError.emptyFrames
        }
        let width = firstFrame.width
        let height = firstFrame.height
        guard width > 0, height > 0 else {
            throw ScrollStitchError.decodeFailed
        }
        for frame in frames where frame.width != width || frame.height != height {
            throw ScrollStitchError.decodeFailed
        }
        guard frames.count > 1 else {
            return StitchedImage(image: firstFrame, frameCount: 1)
        }
        guard var previous = Self.decode(firstFrame) else {
            throw ScrollStitchError.decodeFailed
        }
        let bytesPerRow = previous.bytesPerRow
        var output = previous.pixels
        var outputHeight = height
        var stitchedCount = 1
        var previousFeatures: RowFeatures?

        for frame in frames.dropFirst() {
            guard let next = Self.decode(frame) else {
                throw ScrollStitchError.decodeFailed
            }
            var nextFeatures: RowFeatures?
            let offset = Self.bestOffset(
                previous: previous,
                previousFeatures: &previousFeatures,
                next: next,
                nextFeatures: &nextFeatures,
                minimumOverlap: minimumOverlap,
                maximumSearchDistance: maximumSearchDistance,
                tolerance: overlapTolerance
            )
            guard let offset else {
                // 第一对就找不到重叠：还拼不出内容，按约定抛错；否则保留已拼好的部分。
                if stitchedCount == 1 {
                    throw ScrollStitchError.noOverlap
                }
                break
            }
            guard offset > 0 else {
                // 内容没有继续滚动（或已经到底）：停止追加，返回已有内容。
                break
            }
            // 后一帧底部 offset 行是相对上一帧新增的内容，只追加这些行。
            let newRowsStart = (height - offset) * bytesPerRow
            output.append(contentsOf: next.pixels[newRowsStart..<(height * bytesPerRow)])
            outputHeight += offset
            stitchedCount += 1
            previous = next
            previousFeatures = nextFeatures
        }

        guard stitchedCount > 1 else {
            // 第一对偏移就是 0：没有滚动，只返回首帧。
            return StitchedImage(image: firstFrame, frameCount: 1)
        }
        guard let image = Self.makeImage(
            width: width,
            height: outputHeight,
            bytesPerRow: bytesPerRow,
            pixels: output
        ) else {
            throw ScrollStitchError.decodeFailed
        }
        return StitchedImage(image: image, frameCount: stitchedCount)
    }

    /// `next` 相对 `previous` 向上滚动的像素数；找不到可信重叠时返回 nil。
    ///
    /// 返回 0 表示两帧内容基本相同（没有滚动）。
    func findOffset(previous: CGImage, next: CGImage) -> Int? {
        guard previous.width == next.width,
              previous.height == next.height,
              previous.width > 0,
              previous.height > 0,
              let previousPixels = Self.decode(previous),
              let nextPixels = Self.decode(next)
        else {
            return nil
        }
        var previousFeatures: RowFeatures?
        var nextFeatures: RowFeatures?
        return Self.bestOffset(
            previous: previousPixels,
            previousFeatures: &previousFeatures,
            next: nextPixels,
            nextFeatures: &nextFeatures,
            minimumOverlap: minimumOverlap,
            maximumSearchDistance: maximumSearchDistance,
            tolerance: overlapTolerance
        )
    }
}

// MARK: - 解码与像素缓冲

private struct DecodedFrame {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let pixels: [UInt8]
}

/// 每行 5 个 Float 特征，按行内交错存放：`values[row * featureCount + feature]`。
private struct RowFeatures {
    let values: [Float]
}

private extension ScrollStitcher {
    /// 1:1、无插值地把 `CGImage` 解码成紧凑的 RGBA8 像素。
    static func decode(_ image: CGImage) -> DecodedFrame? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let drewPixels = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  )
            else {
                return false
            }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drewPixels else { return nil }
        return DecodedFrame(width: width, height: height, bytesPerRow: bytesPerRow, pixels: pixels)
    }

    /// 用 vDSP 计算每行统计特征，供一维滑动匹配使用。
    static func rowFeatures(of frame: DecodedFrame) -> RowFeatures {
        let width = frame.width
        let height = frame.height
        guard width > 0, height > 0 else { return RowFeatures(values: []) }
        var values = [Float](repeating: 0, count: height * featureCount)
        var rowFloats = [Float](repeating: 0, count: width * 4)
        var luminance = [Float](repeating: 0, count: width)
        var gradient = [Float](repeating: 0, count: width)
        let inverseWidth = 1.0 / Float(width)
        let inverseEdgeCount = width > 1 ? 1.0 / Float(width - 1) : 0

        frame.pixels.withUnsafeBufferPointer { pixels in
            rowFloats.withUnsafeMutableBufferPointer { rowBuffer in
                luminance.withUnsafeMutableBufferPointer { luminanceBuffer in
                    gradient.withUnsafeMutableBufferPointer { gradientBuffer in
                        guard let pixelBase = pixels.baseAddress,
                              let rowBase = rowBuffer.baseAddress,
                              let luminanceBase = luminanceBuffer.baseAddress,
                              let gradientBase = gradientBuffer.baseAddress
                        else {
                            return
                        }
                        for row in 0..<height {
                            let rowPointer = pixelBase + row * frame.bytesPerRow
                            vDSP_vfltu8(rowPointer, 1, rowBase, 1, vDSP_Length(width * 4))
                            var sumRed: Float = 0
                            var sumGreen: Float = 0
                            var sumBlue: Float = 0
                            vDSP_sve(rowBase, 4, &sumRed, vDSP_Length(width))
                            vDSP_sve(rowBase + 1, 4, &sumGreen, vDSP_Length(width))
                            vDSP_sve(rowBase + 2, 4, &sumBlue, vDSP_Length(width))
                            // 亮度 = R + G + B（0...765）。
                            vDSP_vadd(rowBase, 4, rowBase + 1, 4, luminanceBase, 1, vDSP_Length(width))
                            vDSP_vadd(luminanceBase, 1, rowBase + 2, 4, luminanceBase, 1, vDSP_Length(width))
                            var sumSquares: Float = 0
                            vDSP_svesq(luminanceBase, 1, &sumSquares, vDSP_Length(width))
                            var edgeSum: Float = 0
                            if width > 1 {
                                // 相邻亮度差 = luminance[i] - luminance[i + 1]。
                                vDSP_vsub(luminanceBase + 1, 1, luminanceBase, 1, gradientBase, 1, vDSP_Length(width - 1))
                                vDSP_vabs(gradientBase, 1, gradientBase, 1, vDSP_Length(width - 1))
                                vDSP_sve(gradientBase, 1, &edgeSum, vDSP_Length(width - 1))
                            }
                            let meanRed = sumRed * inverseWidth
                            let meanGreen = sumGreen * inverseWidth
                            let meanBlue = sumBlue * inverseWidth
                            let meanLuminance = (sumRed + sumGreen + sumBlue) * inverseWidth
                            let variance = max(0, sumSquares * inverseWidth - meanLuminance * meanLuminance)
                            let base = row * featureCount
                            values[base] = meanRed
                            values[base + 1] = meanGreen
                            values[base + 2] = meanBlue
                            // 亮度标准差范围 0...255，与通道均值同量级。
                            values[base + 3] = variance.squareRoot() / 3
                            values[base + 4] = edgeSum * inverseEdgeCount / 3
                        }
                    }
                }
            }
        }
        return RowFeatures(values: values)
    }

    /// 行特征的一维滑动匹配：返回 `next` 每行与 `previous` 下移 offset 行后的平均特征差。
    static func featureScores(
        previous: RowFeatures,
        next: RowFeatures,
        height: Int,
        maxDistance: Int
    ) -> [Float] {
        var scores = [Float](repeating: .greatestFiniteMagnitude, count: maxDistance + 2)
        guard height > 0,
              previous.values.count == height * featureCount,
              next.values.count == height * featureCount
        else {
            return scores
        }
        var differences = [Float](repeating: 0, count: height)
        previous.values.withUnsafeBufferPointer { previousValues in
            next.values.withUnsafeBufferPointer { nextValues in
                differences.withUnsafeMutableBufferPointer { differenceBuffer in
                    guard let previousBase = previousValues.baseAddress,
                          let nextBase = nextValues.baseAddress,
                          let differenceBase = differenceBuffer.baseAddress
                    else {
                        return
                    }
                    for offset in 1...maxDistance {
                        let overlap = height - offset
                        var total: Float = 0
                        for feature in 0..<featureCount {
                            let previousStart = previousBase + offset * featureCount + feature
                            let nextStart = nextBase + feature
                            vDSP_vsub(
                                previousStart, featureCount,
                                nextStart, featureCount,
                                differenceBase, 1,
                                vDSP_Length(overlap)
                            )
                            vDSP_vabs(differenceBase, 1, differenceBase, 1, vDSP_Length(overlap))
                            var featureTotal: Float = 0
                            vDSP_sve(differenceBase, 1, &featureTotal, vDSP_Length(overlap))
                            total += featureTotal
                        }
                        scores[offset] = total / Float(overlap)
                    }
                }
            }
        }
        return scores
    }

    /// 核心：在 `next` 相对 `previous` 向上滚动的若干像素里找出最可信的 offset。
    static func bestOffset(
        previous: DecodedFrame,
        previousFeatures: inout RowFeatures?,
        next: DecodedFrame,
        nextFeatures: inout RowFeatures?,
        minimumOverlap: Int,
        maximumSearchDistance: Int,
        tolerance: Double
    ) -> Int? {
        guard previous.width == next.width,
              previous.height == next.height,
              previous.width > 0,
              previous.height > 0
        else {
            return nil
        }
        let height = previous.height
        let maxDistance = min(maximumSearchDistance, height - max(minimumOverlap, 1))
        guard maxDistance >= 1 else { return nil }
        let clampedTolerance = max(tolerance, 0)

        // 1) 两帧基本相同：内容没有滚动。
        if let stationaryDifference = fullMeanAbsDiff(
            previous: previous,
            next: next,
            offset: 0,
            tolerance: clampedTolerance
        ), stationaryDifference <= clampedTolerance {
            return 0
        }

        // 2) 行特征一维滑动，圈出候选偏移。
        if previousFeatures == nil {
            previousFeatures = rowFeatures(of: previous)
        }
        if nextFeatures == nil {
            nextFeatures = rowFeatures(of: next)
        }
        guard let previousRowFeatures = previousFeatures,
              let nextRowFeatures = nextFeatures
        else {
            return nil
        }
        let scores = featureScores(
            previous: previousRowFeatures,
            next: nextRowFeatures,
            height: height,
            maxDistance: maxDistance
        )
        var candidates: [Int] = []
        for offset in 1...maxDistance {
            let score = scores[offset]
            let left = offset > 1 ? scores[offset - 1] : Float.greatestFiniteMagnitude
            let right = offset < maxDistance ? scores[offset + 1] : Float.greatestFiniteMagnitude
            if score <= left, score <= right, score < left || score < right {
                candidates.append(offset)
            }
        }
        candidates.sort { lhs, rhs in
            let leftScore = scores[lhs]
            let rightScore = scores[rhs]
            return leftScore == rightScore ? lhs < rhs : leftScore < rightScore
        }
        if candidates.count > profileCandidateLimit {
            candidates.removeLast(candidates.count - profileCandidateLimit)
        }
        // 特征值出现并列时可能漏掉真实偏移，把特征差最小的偏移也补进候选。
        if maxDistance >= 1 {
            var bestFeatureOffset = 1
            for offset in 2...maxDistance where scores[offset] < scores[bestFeatureOffset] {
                bestFeatureOffset = offset
            }
            if !candidates.contains(bestFeatureOffset) {
                candidates.insert(bestFeatureOffset, at: 0)
            }
        }
        guard !candidates.isEmpty else { return nil }

        // 3) 稀疏二维采样校验，排序出最可能的几个偏移。
        var ranked = candidates.map { offset -> (offset: Int, difference: Double) in
            (offset, sampledMeanAbsDiff(previous: previous, next: next, offset: offset))
        }
        ranked.sort { lhs, rhs in
            lhs.difference == rhs.difference ? lhs.offset < rhs.offset : lhs.difference < rhs.difference
        }
        guard !ranked.isEmpty else { return nil }

        // 4) 全分辨率逐通道验证 + 歧义保护。
        var accepted: [(offset: Int, difference: Double)] = []
        for candidate in ranked.prefix(verificationCandidateLimit) {
            if let difference = fullMeanAbsDiff(
                previous: previous,
                next: next,
                offset: candidate.offset,
                tolerance: clampedTolerance
            ) {
                accepted.append((candidate.offset, difference))
            }
        }
        guard !accepted.isEmpty else { return nil }
        accepted.sort { lhs, rhs in
            lhs.difference == rhs.difference ? lhs.offset < rhs.offset : lhs.difference < rhs.difference
        }
        if accepted.count > 1, accepted[1].difference - accepted[0].difference < ambiguityMargin {
            // 多个不同偏移同样可信：周期内容或大片均匀区域，宁可不拼。
            return nil
        }
        return accepted[0].offset
    }

    /// 稀疏二维采样的逐通道平均绝对差，用于候选排序。
    static func sampledMeanAbsDiff(previous: DecodedFrame, next: DecodedFrame, offset: Int) -> Double {
        let width = previous.width
        let height = previous.height
        let overlap = height - offset
        guard offset >= 0, overlap > 0, width > 0 else { return .greatestFiniteMagnitude }
        let rowStep = max(1, overlap / sampledRowLimit)
        let columnStep = max(1, width / sampledColumnLimit)
        // 不同候选的采样行起点错开，避免周期性内容在固定采样行上产生系统性偏差。
        let rowStart = offset % rowStep
        var sum = 0
        var sampleCount = 0
        previous.pixels.withUnsafeBufferPointer { previousPixels in
            next.pixels.withUnsafeBufferPointer { nextPixels in
                var row = rowStart
                while row < overlap {
                    let previousRowStart = (row + offset) * previous.bytesPerRow
                    let nextRowStart = row * next.bytesPerRow
                    var column = 0
                    while column < width {
                        let previousIndex = previousRowStart + column * 4
                        let nextIndex = nextRowStart + column * 4
                        sum += abs(Int(previousPixels[previousIndex]) - Int(nextPixels[nextIndex]))
                        sum += abs(Int(previousPixels[previousIndex + 1]) - Int(nextPixels[nextIndex + 1]))
                        sum += abs(Int(previousPixels[previousIndex + 2]) - Int(nextPixels[nextIndex + 2]))
                        sampleCount += 3
                        column += columnStep
                    }
                    row += rowStep
                }
            }
        }
        guard sampleCount > 0 else { return .greatestFiniteMagnitude }
        return Double(sum) / Double(sampleCount)
    }

    /// 全分辨率逐通道平均绝对差；一旦累计差已经超过容差就提前放弃并返回 nil。
    static func fullMeanAbsDiff(
        previous: DecodedFrame,
        next: DecodedFrame,
        offset: Int,
        tolerance: Double
    ) -> Double? {
        let width = previous.width
        let height = previous.height
        let overlap = height - offset
        guard offset >= 0, overlap > 0, width > 0,
              previous.width == next.width, previous.height == next.height
        else {
            return nil
        }
        let channelCount = 3 * overlap * width
        let abortThreshold = tolerance * Double(channelCount)
        var sum = 0
        var aborted = false
        previous.pixels.withUnsafeBufferPointer { previousPixels in
            next.pixels.withUnsafeBufferPointer { nextPixels in
                for row in 0..<overlap {
                    let previousRowStart = (row + offset) * previous.bytesPerRow
                    let nextRowStart = row * next.bytesPerRow
                    var rowSum = 0
                    var column = 0
                    while column < width {
                        let previousIndex = previousRowStart + column * 4
                        let nextIndex = nextRowStart + column * 4
                        rowSum += abs(Int(previousPixels[previousIndex]) - Int(nextPixels[nextIndex]))
                        rowSum += abs(Int(previousPixels[previousIndex + 1]) - Int(nextPixels[nextIndex + 1]))
                        rowSum += abs(Int(previousPixels[previousIndex + 2]) - Int(nextPixels[nextIndex + 2]))
                        column += 1
                    }
                    sum += rowSum
                    if Double(sum) > abortThreshold {
                        aborted = true
                        break
                    }
                }
            }
        }
        guard !aborted else { return nil }
        return Double(sum) / Double(channelCount)
    }

    /// 把 RGBA8 像素缓冲包装成 `CGImage`。
    static func makeImage(width: Int, height: Int, bytesPerRow: Int, pixels: [UInt8]) -> CGImage? {
        guard width > 0, height > 0, bytesPerRow == width * 4, pixels.count == bytesPerRow * height else {
            return nil
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
