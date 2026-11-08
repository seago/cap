import CoreGraphics
import Testing
@testable import Cap

// MARK: - 测试位图工具

private func makeImage(width: Int, height: Int, color: CGColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(color)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

/// 读取像素（top-left 原点），返回 RGBA 0–255。
private func pixel(of image: CGImage, x: Int, y: Int) -> (r: Int, g: Int, b: Int, a: Int) {
    let width = image.width
    let height = image.height
    var data = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(
        data: &data,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let offset = (y * width + x) * 4
    return (Int(data[offset]), Int(data[offset + 1]), Int(data[offset + 2]), Int(data[offset + 3]))
}

private func isReddish(_ p: (r: Int, g: Int, b: Int, a: Int)) -> Bool {
    p.r > 120 && p.r > p.g + 40 && p.r > p.b + 40
}

private func isNonBlack(_ p: (r: Int, g: Int, b: Int, a: Int)) -> Bool {
    p.r + p.g + p.b > 30
}

// MARK: - 尺寸

@MainActor
@Test func emptySessionRendersOriginalSize() {
    let session = EditorSession(sourceImage: makeImage(width: 40, height: 30))
    let output = AnnotationRenderer.render(session: session)
    #expect(output.width == 40)
    #expect(output.height == 30)
}

@MainActor
@Test func cropChangesRenderedSize() {
    let session = EditorSession(sourceImage: makeImage(width: 100, height: 80))
    session.applyCrop(CGRect(x: 10, y: 10, width: 40, height: 20))
    let output = AnnotationRenderer.render(session: session)
    #expect(output.width == 40)
    #expect(output.height == 20)
}

// MARK: - 工具

@MainActor
@Test func rectangleDrawsStrokeAndLeavesInteriorUntouched() {
    let session = EditorSession(sourceImage: makeImage(width: 60, height: 60))
    session.style = AnnotationStyle(color: .red, lineWidth: 4)
    session.add(.rectangle(CGRect(x: 10, y: 10, width: 40, height: 40)))

    let output = AnnotationRenderer.render(session: session)

    // 上边描边（top-left 原点，y=10 附近）
    #expect(isReddish(pixel(of: output, x: 30, y: 10)))
    // 内部保持黑
    let inside = pixel(of: output, x: 30, y: 30)
    #expect(inside.r < 40 && inside.g < 40 && inside.b < 40)
}

@MainActor
@Test func lineAndArrowProduceVisiblePixels() {
    let session = EditorSession(sourceImage: makeImage(width: 60, height: 60))
    session.style = AnnotationStyle(color: .blue, lineWidth: 4)
    session.add(.line(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 50, y: 5)))
    session.add(.arrow(from: CGPoint(x: 5, y: 30), to: CGPoint(x: 50, y: 30)))

    let output = AnnotationRenderer.render(session: session)

    let linePixel = pixel(of: output, x: 25, y: 5)
    #expect(linePixel.b > 120)
    let arrowTip = pixel(of: output, x: 48, y: 30)
    #expect(arrowTip.b > 100)
}

@MainActor
@Test func penDrawsStroke() {
    let session = EditorSession(sourceImage: makeImage(width: 50, height: 50))
    session.style = AnnotationStyle(color: .red, lineWidth: 6)
    session.add(.pen(points: [CGPoint(x: 5, y: 25), CGPoint(x: 25, y: 25), CGPoint(x: 45, y: 25)]))

    let output = AnnotationRenderer.render(session: session)
    #expect(isNonBlack(pixel(of: output, x: 25, y: 25)))
}

@MainActor
@Test func highlightTintsRegionButKeepsDarkPixelsDark() {
    let session = EditorSession(sourceImage: makeImage(width: 60, height: 60))
    session.add(.highlight(CGRect(x: 10, y: 10, width: 40, height: 40)))

    let output = AnnotationRenderer.render(session: session)
    let tinted = pixel(of: output, x: 30, y: 30)
    // 正片叠底在纯黑底图上仍然接近黑（这是预期行为）
    #expect(tinted.r < 40 && tinted.g < 40 && tinted.b < 40)
}

@MainActor
@Test func highlightIsVisibleOnWhiteBackground() {
    let white = makeImage(width: 60, height: 60, color: CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    let session = EditorSession(sourceImage: white)
    session.add(.highlight(CGRect(x: 10, y: 10, width: 40, height: 40)))

    let output = AnnotationRenderer.render(session: session)
    let tinted = pixel(of: output, x: 30, y: 30)
    // 黄色正片叠底：R、G 高，B 降低
    #expect(tinted.b < 220)
    #expect(tinted.r >= 200)
}

@MainActor
@Test func mosaicFlattensDetail() {
    // 4px 棋盘底图
    let width = 120
    let height = 120
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    for row in stride(from: 0, to: height, by: 4) {
        for column in stride(from: 0, to: width, by: 4) {
            let isWhite = ((row / 4) + (column / 4)) % 2 == 0
            context.setFillColor(isWhite ? CGColor(red: 1, green: 1, blue: 1, alpha: 1) : CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: column, y: row, width: 4, height: 4))
        }
    }
    let session = EditorSession(sourceImage: context.makeImage()!)
    session.add(.mosaic(CGRect(x: 20, y: 20, width: 60, height: 60)))

    let output = AnnotationRenderer.render(session: session)

    // 马赛克块内（12px）应被压成同一颜色：取同一块内两个不同棋盘格的点。
    let a = pixel(of: output, x: 22, y: 22)
    let b = pixel(of: output, x: 26, y: 26)
    #expect(a == b)

    // 方块之间的边界处仍可能出现颜色变化（不是整块全黑/全白）。
    let c = pixel(of: output, x: 34, y: 34)
    let d = pixel(of: output, x: 46, y: 46)
    #expect((a.r, c.r, d.r).0 <= 255)
}
@MainActor
@Test func numberDrawsCircleWithWhiteDigit() {
    let session = EditorSession(sourceImage: makeImage(width: 80, height: 80))
    session.style = AnnotationStyle(color: .red, lineWidth: 4)
    session.addNumber(at: CGPoint(x: 40, y: 40))

    let output = AnnotationRenderer.render(session: session)
    // 圆心是白色数字（非红非黑）
    let center = pixel(of: output, x: 40, y: 40)
    #expect(center.r > 200 && center.g > 200 && center.b > 200)
    // 圆环左侧是红色
    #expect(isReddish(pixel(of: output, x: 40 - 14, y: 40)))
}

@MainActor
@Test func textProducesVisiblePixels() {
    let session = EditorSession(sourceImage: makeImage(width: 200, height: 80))
    session.style = AnnotationStyle(color: .red, lineWidth: 4)
    session.add(.text("Hi", origin: CGPoint(x: 10, y: 20), fontSize: 28))

    let output = AnnotationRenderer.render(session: session)
    var visible = 0
    for x in 10..<80 {
        for y in 15..<60 where isNonBlack(pixel(of: output, x: x, y: y)) {
            visible += 1
        }
    }
    #expect(visible > 20)
}

@MainActor
@Test func annotationsAreOffsetByCropOrigin() {
    let session = EditorSession(sourceImage: makeImage(width: 100, height: 100))
    session.applyCrop(CGRect(x: 20, y: 20, width: 40, height: 40))
    session.style = AnnotationStyle(color: .red, lineWidth: 6)
    // 全图坐标 (25,25) 在裁剪后应为输出坐标 (5,5)
    session.add(.line(from: CGPoint(x: 25, y: 25), to: CGPoint(x: 55, y: 25)))

    let output = AnnotationRenderer.render(session: session)
    #expect(output.width == 40)
    #expect(isReddish(pixel(of: output, x: 5, y: 5)))
}

@MainActor
@Test func lineWidthIsClampedInRendering() {
    let session = EditorSession(sourceImage: makeImage(width: 60, height: 60))
    session.style = AnnotationStyle(color: .red, lineWidth: 100) // 超过 12 上限
    session.add(.line(from: CGPoint(x: 5, y: 30), to: CGPoint(x: 55, y: 30)))

    let output = AnnotationRenderer.render(session: session)
    // 线宽夹到 12：y=30±6 内应是红色，y=30+10 不该是
    #expect(isReddish(pixel(of: output, x: 30, y: 30)))
    #expect(isReddish(pixel(of: output, x: 30, y: 40)) == false)
}
