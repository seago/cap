import AppKit
import CoreGraphics

/// 管理所有贴图钉屏窗口。
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
        var model = PinnedImageModel(imageSize: imageSize, scale: initialScale(for: imageSize))
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

        let window = PinnedImageWindow(frame: CGRect(origin: origin, size: displaySize))
        let view = PinnedImageView(image: image, model: model)
        window.contentView = view

        view.onZoom = { [weak self, weak window] factor in
            guard let self, let window, let view = window.contentView as? PinnedImageView else { return }
            let selectedScreen = window.screen?.visibleFrame ?? visibleFrame
            let newScale = PinnedImageModel.clampScale(model.scale * factor)
            let oldSize = model.displaySize
            let currentOrigin = window.frame.origin
            // 锚点 = 鼠标在窗口内的位置（AppKit 左下原点）
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
            var frame = CGRect(origin: newOrigin, size: newSize)
            frame.origin.x = min(max(frame.origin.x, selectedScreen.minX), max(selectedScreen.minX, selectedScreen.maxX - newSize.width))
            frame.origin.y = min(max(frame.origin.y, selectedScreen.minY), max(selectedScreen.minY, selectedScreen.maxY - newSize.height))
            window.setFrame(frame, display: true)
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

        window.orderFront(nil)
        window.makeKey()
        window.makeFirstResponder(view)
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
