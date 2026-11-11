import AppKit
import CoreGraphics

/// 管理所有贴图钉屏窗口。
///
/// Space / 全屏切换后 AppKit 有时会把浮窗留在已销毁的 Space 里（`isVisible` 仍为 true，
/// 但实际不再参与合成）。这里监听 active space 变化，把已经不在屏幕上的钉屏按原位置、
/// 原缩放、原穿透状态重建一次，保证切窗口/切 Space 后仍然可见。
@MainActor
final class PinnedImageController {
    private var windows: [PinnedImageWindow] = []
    private let clipboardWriter = ClipboardWriter()

    var hasPins: Bool { !windows.isEmpty }
    var allClickThrough: Bool { !windows.isEmpty && windows.allSatisfy(\.clickThrough) }

    /// 钉住一张图。`near` 用来决定初始位置（通常是被来源窗口的 frame）。
    @discardableResult
    func pin(image: CGImage, near sourceFrame: CGRect?) -> PinnedImageWindow {
        let imageSize = CGSize(width: image.width, height: image.height)
        let model = PinnedImageModel(imageSize: imageSize, scale: initialScale(for: imageSize))
        let displaySize = model.displaySize

        let visibleFrame = NSScreen.screens.first(where: { $0.frame.intersects(sourceFrame ?? .zero) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        var origin: CGPoint
        if let sourceFrame {
            origin = CGPoint(x: sourceFrame.minX + 24, y: sourceFrame.minY - displaySize.height - 24)
            if origin.y < visibleFrame.minY || origin.y + displaySize.height > visibleFrame.maxY {
                origin = CGPoint(x: sourceFrame.minX + 24, y: sourceFrame.maxY + 24)
            }
        } else {
            origin = CGPoint(x: visibleFrame.midX - displaySize.width / 2, y: visibleFrame.midY - displaySize.height / 2)
        }
        // 多张钉屏错开摆放，避免完全重叠。
        let cascade = CGFloat(windows.count % 8) * 18
        origin.x += cascade
        origin.y -= cascade
        origin.x = min(max(origin.x, visibleFrame.minX), max(visibleFrame.minX, visibleFrame.maxX - displaySize.width))
        origin.y = min(max(origin.y, visibleFrame.minY), max(visibleFrame.minY, visibleFrame.maxY - displaySize.height))

        let window = makeWindow(
            image: image,
            frame: CGRect(origin: origin, size: displaySize),
            scale: model.scale,
            clickThrough: false,
            activate: true
        )
        windows.append(window)
        Log.pin.notice("Pinned image \(image.width, privacy: .public)x\(image.height, privacy: .public) scale=\(Double(model.scale), privacy: .public)")
        return window
    }

    /// 初始缩放：大图缩到屏幕内，小图保持 100%。
    private func initialScale(for imageSize: CGSize) -> CGFloat {
        let visible = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let maxWidth = visible.width * 0.6
        let maxHeight = visible.height * 0.8
        guard imageSize.width > maxWidth || imageSize.height > maxHeight else { return 1 }
        let widthScale = maxWidth / imageSize.width
        let heightScale = maxHeight / imageSize.height
        return PinnedImageModel.clampScale(min(widthScale, heightScale))
    }

    // MARK: - 窗口构造

    private func makeWindow(
        image: CGImage,
        frame: CGRect,
        scale: CGFloat,
        clickThrough: Bool,
        activate: Bool
    ) -> PinnedImageWindow {
        let imageSize = CGSize(width: image.width, height: image.height)
        var model = PinnedImageModel(imageSize: imageSize, scale: scale)
        let window = PinnedImageWindow(frame: frame)
        let view = PinnedImageView(image: image, model: model)
        window.contentView = view

        view.onZoom = { [weak self, weak window] factor in
            guard let self, let window, let view = window.contentView as? PinnedImageView else { return }
            let selectedScreen = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? frame
            let newScale = PinnedImageModel.clampScale(model.scale * factor)
            let oldSize = model.displaySize
            let currentOrigin = window.frame.origin
            let mouse = window.convertPoint(fromScreen: NSEvent.mouseLocation)
            let anchor = CGPoint(
                x: min(max(mouse.x, 0), oldSize.width),
                y: min(max(mouse.y, 0), oldSize.height)
            )
            model.setScale(newScale)
            let newOrigin = PinnedImageModel.anchoredOrigin(
                newScale: newScale,
                model: model,
                oldSize: oldSize,
                currentOrigin: currentOrigin,
                anchorInWindow: anchor
            )
            let newSize = model.displaySize
            var updatedFrame = CGRect(origin: newOrigin, size: newSize)
            updatedFrame.origin.x = min(max(updatedFrame.origin.x, selectedScreen.minX), max(selectedScreen.minX, selectedScreen.maxX - newSize.width))
            updatedFrame.origin.y = min(max(updatedFrame.origin.y, selectedScreen.minY), max(selectedScreen.minY, selectedScreen.maxY - newSize.height))
            window.setFrame(updatedFrame, display: true)
            view.update(model: model)
        }
        view.onClose = { [weak self, weak window] in
            guard let window else { return }
            self?.close(window)
        }
        view.onToggleClickThrough = { [weak self, weak window] in
            guard let window else { return }
            self?.toggleClickThrough(window)
        }
        view.onCopy = { [weak self] in
            do {
                try self?.clipboardWriter.write(image)
            } catch {
                Log.pin.error("Copy pinned image failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        if clickThrough {
            window.setClickThrough(true)
        }
        window.orderFront(nil)
        if activate {
            window.makeKey()
            window.makeFirstResponder(view)
        }
        return window
    }

    // MARK: - Space 切换恢复

    // MARK: - 操作

    func close(_ window: PinnedImageWindow) {
        window.orderOut(nil)
        window.close()
        windows.removeAll { $0 === window }
    }

    func closeAll() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }

    func toggleClickThrough(_ window: PinnedImageWindow) {
        window.setClickThrough(!window.clickThrough)
        Log.pin.notice("Pinned image click-through=\(window.clickThrough, privacy: .public)")
    }

    /// 所有贴图一起切换点击穿透（穿透后鼠标点不到窗口，需要热键恢复）。
    func toggleClickThroughAll() {
        guard !windows.isEmpty else { return }
        let target = !allClickThrough
        for window in windows {
            window.setClickThrough(target)
        }
        Log.pin.notice("All pinned images click-through=\(target, privacy: .public)")
    }
}
