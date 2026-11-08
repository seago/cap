import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 历史缩略图生成，见 `DESIGN.md` §3.6 / §6.1：`History/thumbs/{uuid}.jpg`。
///
/// 规则：
/// - 等比缩放到最大宽度 320px（JPEG / sRGB / 无 alpha 通道），纵横比保持；
/// - 宽度不超过 320px 的图不放大，直接按原尺寸编码，避免无意义的重采样与模糊。
enum Thumbnailer {
    /// 缩略图最大像素宽度，`DESIGN.md` §6.1：320px。
    static let maxPixelWidth = 320
    /// JPEG 压缩质量，与保存默认值一致（`DESIGN.md` §3.5：0.85）。
    static let compressionQuality: CGFloat = 0.85

    /// 缩略图像素尺寸。
    struct PixelSize: Equatable, Sendable {
        let width: Int
        let height: Int
    }

    /// 计算等比缩放后的像素尺寸：宽度上限 `maxPixelWidth`，不放大小图。
    static func scaledSize(
        width: Int,
        height: Int,
        maxPixelWidth: Int = Thumbnailer.maxPixelWidth
    ) -> PixelSize {
        guard width > 0, height > 0, maxPixelWidth > 0 else {
            return PixelSize(width: 0, height: 0)
        }
        guard width > maxPixelWidth else {
            return PixelSize(width: width, height: height)
        }
        let scaledHeight = max(1, Int((Double(height) * Double(maxPixelWidth) / Double(width)).rounded()))
        return PixelSize(width: maxPixelWidth, height: scaledHeight)
    }

    /// 生成缩略图 JPEG 数据；编码失败返回 `nil`。
    static func jpegData(
        from image: CGImage,
        maxPixelWidth: Int = Thumbnailer.maxPixelWidth,
        compressionQuality: CGFloat = Thumbnailer.compressionQuality
    ) -> Data? {
        guard let scaled = scaledImage(from: image, maxPixelWidth: maxPixelWidth) else {
            return nil
        }
        let buffer = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            buffer,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        let options = [kCGImageDestinationLossyCompressionQuality: compressionQuality] as CFDictionary
        CGImageDestinationAddImage(destination, scaled, options)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return buffer as Data
    }

    /// 等比缩放为 RGB（无 alpha）位图；尺寸不变时直接返回原图。
    static func scaledImage(
        from image: CGImage,
        maxPixelWidth: Int = Thumbnailer.maxPixelWidth
    ) -> CGImage? {
        let target = scaledSize(
            width: image.width,
            height: image.height,
            maxPixelWidth: maxPixelWidth
        )
        guard target.width > 0, target.height > 0 else {
            return nil
        }
        if target.width == image.width, target.height == image.height {
            return image
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: target.width,
            height: target.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: target.width, height: target.height))
        return context.makeImage()
    }
}
