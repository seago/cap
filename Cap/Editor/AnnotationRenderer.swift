import AppKit
import CoreGraphics

/// 把 `EditorSession` 的标注渲染成位图。
///
/// 坐标约定：标注坐标使用**原图像素坐标，原点在左上角**（与 AppKit 视图的 y 轴相反，
/// 因此渲染时统一翻转到 CoreGraphics 的左下原点坐标系）。
enum AnnotationRenderer {
    /// 马赛克块大小（像素）。
    static let mosaicBlockSize: CGFloat = 12

    /// 渲染最终图像。
    @MainActor
    static func render(session: EditorSession) -> CGImage {
        let outputSize = session.outputSize
        let width = max(1, Int(outputSize.width.rounded()))
        let height = max(1, Int(outputSize.height.rounded()))

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return session.sourceImage
        }

        let cropOrigin = session.cropRect?.origin ?? .zero

        // 1. 底图（裁剪后）。
        let baseImage: CGImage
        if let crop = session.cropRect, let cropped = session.sourceImage.cropping(to: crop) {
            baseImage = cropped
        } else {
            baseImage = session.sourceImage
        }

        context.interpolationQuality = .high
        context.draw(baseImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 2. 标注：把左上原点坐标转成输出图像坐标系。
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        for annotation in session.annotations {
            draw(annotation, in: context, outputSize: CGSize(width: width, height: height), cropOrigin: cropOrigin, source: session.sourceImage)
        }
        context.restoreGState()

        return context.makeImage() ?? session.sourceImage
    }

    // MARK: - 绘制

    private static func draw(
        _ annotation: Annotation,
        in context: CGContext,
        outputSize: CGSize,
        cropOrigin: CGPoint,
        source: CGImage
    ) {
        let color = cgColor(for: annotation.style.color)
        let lineWidth = annotation.style.clampedLineWidth()

        switch annotation.kind {
        case .rectangle(let rect):
            let r = outputRect(rect, cropOrigin: cropOrigin)
            context.setStrokeColor(color)
            context.setLineWidth(lineWidth)
            context.stroke(r)

        case .line(let from, let to):
            context.setStrokeColor(color)
            context.setLineWidth(lineWidth)
            context.beginPath()
            context.move(to: outputPoint(from, cropOrigin: cropOrigin))
            context.addLine(to: outputPoint(to, cropOrigin: cropOrigin))
            context.strokePath()

        case .arrow(let from, let to):
            drawArrow(from: outputPoint(from, cropOrigin: cropOrigin),
                      to: outputPoint(to, cropOrigin: cropOrigin),
                      lineWidth: lineWidth, color: color, in: context)

        case .pen(let points):
            guard let first = points.first else { return }
            context.setStrokeColor(color)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.beginPath()
            context.move(to: outputPoint(first, cropOrigin: cropOrigin))
            for point in points.dropFirst() {
                context.addLine(to: outputPoint(point, cropOrigin: cropOrigin))
            }
            context.strokePath()

        case .highlight(let rect):
            let r = outputRect(rect, cropOrigin: cropOrigin)
            context.saveGState()
            context.setBlendMode(.multiply)
            context.setFillColor(NSColor.systemYellow.withAlphaComponent(0.45).cgColor)
            context.fill(r)
            context.restoreGState()

        case .mosaic(let rect):
            let r = outputRect(rect, cropOrigin: cropOrigin).integral
            guard r.width >= 1, r.height >= 1 else { return }
            drawMosaic(rect: r, in: context, source: source, cropOrigin: cropOrigin)

        case .text(let text, let origin, let fontSize):
            drawText(text,
                     at: outputPoint(origin, cropOrigin: cropOrigin),
                     fontSize: fontSize,
                     color: color,
                     in: context,
                     outputSize: outputSize)

        case .number(let value, let center):
            drawNumber(value,
                       center: outputPoint(center, cropOrigin: cropOrigin),
                       lineWidth: lineWidth,
                       color: color,
                       in: context,
                       outputSize: outputSize)
        }
    }

    private static func drawArrow(
        from: CGPoint,
        to: CGPoint,
        lineWidth: CGFloat,
        color: CGColor,
        in context: CGContext
    ) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let headLength = max(lineWidth * 3, 10)
        let headAngle: CGFloat = .pi / 7

        let left = CGPoint(
            x: to.x - headLength * cos(angle - headAngle),
            y: to.y - headLength * sin(angle - headAngle)
        )
        let right = CGPoint(
            x: to.x - headLength * cos(angle + headAngle),
            y: to.y - headLength * sin(angle + headAngle)
        )

        context.setStrokeColor(color)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.beginPath()
        context.move(to: from)
        context.addLine(to: to)
        context.strokePath()

        context.setFillColor(color)
        context.beginPath()
        context.move(to: to)
        context.addLine(to: left)
        context.addLine(to: right)
        context.closePath()
        context.fillPath()
    }

    private static func drawText(
        _ text: String,
        at point: CGPoint,
        fontSize: CGFloat,
        color: CGColor,
        in context: CGContext,
        outputSize: CGSize
    ) {
        guard !text.isEmpty else { return }
        let nsColor = NSColor(cgColor: color) ?? NSColor.systemRed
        guard let image = textImage(text, fontSize: fontSize, color: nsColor) else { return }
        let rect = CGRect(
            x: point.x,
            y: point.y,
            width: CGFloat(image.width),
            height: CGFloat(image.height)
        )
        drawUprightImage(image, in: rect, context: context)
    }

    private static func drawNumber(
        _ value: Int,
        center: CGPoint,
        lineWidth: CGFloat,
        color: CGColor,
        in context: CGContext,
        outputSize: CGSize
    ) {
        let radius = max(10, lineWidth * 4)
        let circle = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        context.setFillColor(color)
        context.fillEllipse(in: circle)

        let digitSize = radius * 1.3
        guard let image = textImage("\(value)", fontSize: digitSize, color: .white) else { return }
        let rect = CGRect(
            x: center.x - CGFloat(image.width) / 2,
            y: center.y - CGFloat(image.height) / 2,
            width: CGFloat(image.width),
            height: CGFloat(image.height)
        )
        drawUprightImage(image, in: rect, context: context)
    }

    /// 用 AppKit 把文字渲染成小位图（自然方向、不自带翻转问题）。
    private static func textImage(_ text: String, fontSize: CGFloat, color: NSColor) -> CGImage? {
        let font = NSFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        guard textSize.width > 0, textSize.height > 0 else { return nil }

        let padding: CGFloat = 2
        let size = NSSize(width: ceil(textSize.width) + padding * 2, height: ceil(textSize.height) + padding * 2)
        let image = NSImage(size: size)
        image.lockFocus()
        (text as NSString).draw(at: NSPoint(x: padding, y: padding), withAttributes: attributes)
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.cgImage
    }

    /// 在左上原点（y 向下）的上下文中正立绘制位图。
    private static func drawUprightImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }

    private static func drawMosaic(rect: CGRect, in context: CGContext, source: CGImage, cropOrigin: CGPoint) {
        // 从原图裁出区域（CGImage 裁剪使用左上原点像素坐标）。
        let sourceRect = CGRect(
            x: rect.origin.x + cropOrigin.x,
            y: rect.origin.y + cropOrigin.y,
            width: rect.width,
            height: rect.height
        ).integral
        guard let cropped = source.cropping(to: sourceRect) else { return }

        let block = mosaicBlockSize
        let smallWidth = max(1, Int((rect.width / block).rounded(.up)))
        let smallHeight = max(1, Int((rect.height / block).rounded(.up)))

        guard let smallContext = CGContext(
            data: nil,
            width: smallWidth,
            height: smallHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        smallContext.interpolationQuality = .none
        smallContext.draw(cropped, in: CGRect(x: 0, y: 0, width: smallWidth, height: smallHeight))
        guard let smallImage = smallContext.makeImage() else { return }

        context.saveGState()
        context.interpolationQuality = .none
        context.draw(smallImage, in: rect)
        context.restoreGState()
    }

    // MARK: - 坐标与颜色

    /// 左上原点 → 输出图像（已翻转）坐标。
    private static func outputRect(_ rect: CGRect, cropOrigin: CGPoint) -> CGRect {
        CGRect(
            x: rect.origin.x - cropOrigin.x,
            y: rect.origin.y - cropOrigin.y,
            width: rect.width,
            height: rect.height
        )
    }

    private static func outputPoint(_ point: CGPoint, cropOrigin: CGPoint) -> CGPoint {
        CGPoint(x: point.x - cropOrigin.x, y: point.y - cropOrigin.y)
    }

    static func cgColor(for color: AnnotationColor) -> CGColor {
        switch color {
        case .red:
            return NSColor.systemRed.cgColor
        case .yellow:
            return NSColor.systemYellow.cgColor
        case .blue:
            return NSColor.systemBlue.cgColor
        }
    }
}
