import CoreGraphics
import Testing
@testable import Cap

@Test func scaleIsClampedToRange() {
    let model = PinnedImageModel(imageSize: CGSize(width: 100, height: 50), scale: 50)
    #expect(model.scale == PinnedImageModel.maximumScale)

    var shrinking = PinnedImageModel(imageSize: CGSize(width: 100, height: 50), scale: 1)
    shrinking.setScale(0.001)
    #expect(shrinking.scale == PinnedImageModel.minimumScale)
}

@Test func displaySizeFollowsScale() {
    var model = PinnedImageModel(imageSize: CGSize(width: 200, height: 100))
    #expect(model.displaySize == CGSize(width: 200, height: 100))
    model.setScale(2)
    #expect(model.displaySize == CGSize(width: 400, height: 200))
    model.setScale(0.5)
    #expect(model.displaySize == CGSize(width: 100, height: 50))
}

@Test func zoomMultipliesAndClamps() {
    var model = PinnedImageModel(imageSize: CGSize(width: 100, height: 100))
    model.zoom(by: 1.5)
    #expect(model.scale == 1.5)
    model.zoom(by: 100)
    #expect(model.scale == PinnedImageModel.maximumScale)
}

@Test func anchoredOriginKeepsAnchorAtSameScreenPoint() {
    let model = PinnedImageModel(imageSize: CGSize(width: 400, height: 300), scale: 1)
    let oldSize = model.displaySize
    let currentOrigin = CGPoint(x: 100, y: 200)
    let anchor = CGPoint(x: 120, y: 60)
    let screenAnchorBefore = CGPoint(x: currentOrigin.x + anchor.x, y: currentOrigin.y + anchor.y)

    let newOrigin = PinnedImageModel.anchoredOrigin(
        newScale: 2,
        model: model,
        oldSize: oldSize,
        currentOrigin: currentOrigin,
        anchorInWindow: anchor
    )

    // 锚点在窗口内的相对位置不变
    let ratioX = anchor.x / oldSize.width
    let ratioY = anchor.y / oldSize.height
    let newSize = CGSize(width: oldSize.width * 2, height: oldSize.height * 2)
    let screenAnchorAfter = CGPoint(
        x: newOrigin.x + ratioX * newSize.width,
        y: newOrigin.y + ratioY * newSize.height
    )
    #expect(abs(screenAnchorAfter.x - screenAnchorBefore.x) < 0.0001)
    #expect(abs(screenAnchorAfter.y - screenAnchorBefore.y) < 0.0001)
}

@Test func centerAnchorKeepsCenterFixed() {
    let model = PinnedImageModel(imageSize: CGSize(width: 200, height: 100), scale: 1)
    let oldSize = model.displaySize
    let origin = CGPoint(x: 50, y: 50)
    let newOrigin = PinnedImageModel.anchoredOrigin(
        newScale: 2,
        model: model,
        oldSize: oldSize,
        currentOrigin: origin,
        anchorInWindow: CGPoint(x: oldSize.width / 2, y: oldSize.height / 2)
    )
    // 中心点不变：origin + oldSize/2 == newOrigin + newSize/2（缩放 2x）
    let centerBeforeX = origin.x + oldSize.width / 2
    let centerBeforeY = origin.y + oldSize.height / 2
    let centerAfterX = newOrigin.x + oldSize.width
    let centerAfterY = newOrigin.y + oldSize.height
    #expect(abs(centerAfterX - centerBeforeX) < 0.0001)
    #expect(abs(centerAfterY - centerBeforeY) < 0.0001)
}

@Test func zeroOldSizeReturnsOrigin() {
    let model = PinnedImageModel(imageSize: CGSize(width: 10, height: 10))
    let origin = CGPoint(x: 5, y: 7)
    let result = PinnedImageModel.anchoredOrigin(
        newScale: 2, model: model, oldSize: .zero, currentOrigin: origin, anchorInWindow: .zero
    )
    #expect(result == origin)
}

@Test func anchoredOriginClampsRequestedScale() {
    let model = PinnedImageModel(imageSize: CGSize(width: 100, height: 100), scale: 1)
    let origin = CGPoint(x: 0, y: 0)
    let result = PinnedImageModel.anchoredOrigin(
        newScale: 1000,
        model: model,
        oldSize: model.displaySize,
        currentOrigin: origin,
        anchorInWindow: .zero
    )
    // scale 被夹到 8 → 新尺寸 800，锚点在原点 → 新原点不变
    #expect(result == origin)
}
