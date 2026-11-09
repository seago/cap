import AppKit
import CoreGraphics

/// 滚动长截图的失败原因。
enum ScrollCaptureFailure: Error, Equatable, Sendable {
    case alreadyRunning
    /// 没有辅助功能权限，无法向目标 App 发送滚动事件。
    case accessibilityPermissionRequired
    /// 目标区域没有可滚动内容（滚动后画面没变化）。
    case noScrollableContent
    /// 只拼到很少的内容（基本等于单帧）。
    case tooShort
    case captureFailed
    case cancelled

    var userMessage: String {
        switch self {
        case .alreadyRunning:
            return "已经在进行滚动截图。"
        case .accessibilityPermissionRequired:
            return "滚动截图需要「辅助功能」权限，才能自动滚动页面。请在系统设置 → 隐私与安全性 → 辅助功能中勾选 Cap。"
        case .noScrollableContent:
            return "这块区域没有可滚动的内容。请框选一个能上下滚动的页面区域后重试。"
        case .tooShort:
            return "没有截到更多内容，结果和单张截图差不多。"
        case .captureFailed:
            return "滚动过程中截图失败，已保留已截到的部分。"
        case .cancelled:
            return "已取消滚动截图。"
        }
    }
}

extension ScrollCaptureFailure: LocalizedError {
    var errorDescription: String? { userMessage }
}

/// 滚动长截图控制器：反复截取同一区域 + 自动滚动，最后交给 `ScrollStitcher` 拼接。
@MainActor
final class ScrollCaptureController {
    struct Configuration: Sendable {
        /// 最多截多少屏（含第一屏）。
        var maximumFrames = 12
        /// 每步滚动的像素比例（相对选区高度）。
        var scrollRatio: CGFloat = 0.55
        /// 每次滚动后等待画面稳定。
        var settleMilliseconds: UInt64 = 280
        /// 拼接结果至少要比单帧高这么多倍，否则视为没滚动。
        var minimumResultHeightRatio: CGFloat = 1.15
    }

    typealias FrameProvider = @MainActor (_ region: CGRect) async throws -> CGImage
    typealias ScrollAction = @MainActor (_ points: CGFloat, _ location: CGPoint) -> Void
    typealias AccessibilityCheck = @MainActor () -> Bool

    let configuration: Configuration
    private let frameProvider: FrameProvider
    private let scrollAction: ScrollAction
    private let stitcher: ScrollStitcher
    private let accessibilityCheck: AccessibilityCheck
    private let sleep: @MainActor (UInt64) async -> Void

    private(set) var frames: [CGImage] = []
    private(set) var isCancelled = false
    private var isRunning = false

    /// 进度回调：已捕获帧数、最新一帧相对上一帧的滚动像素。
    var onProgress: ((Int, Int?) -> Void)?

    init(
        configuration: Configuration = Configuration(),
        frameProvider: @escaping FrameProvider,
        scrollAction: @escaping ScrollAction,
        stitcher: ScrollStitcher = ScrollStitcher(),
        accessibilityCheck: @escaping AccessibilityCheck = { AXIsProcessTrusted() },
        sleep: @escaping @MainActor (UInt64) async -> Void = { milliseconds in
            try? await Task.sleep(nanoseconds: milliseconds * 1_000_000)
        }
    ) {
        self.configuration = configuration
        self.frameProvider = frameProvider
        self.scrollAction = scrollAction
        self.stitcher = stitcher
        self.accessibilityCheck = accessibilityCheck
        self.sleep = sleep
    }

    var isActive: Bool { isRunning }

    func cancel() {
        isCancelled = true
    }

    /// 执行一次滚动截图。
    /// - Parameters:
    ///   - region: 要截取的屏幕区域（AppKit 屏幕坐标，左下原点）。
    ///   - targetPID: 要发送滚动事件的目标进程。
    ///   - scrollLocation: 滚动事件的作用位置（CG 全局坐标，左上原点）。
    func run(region: CGRect, targetPID: pid_t, scrollLocation: CGPoint) async -> Result<CGImage, ScrollCaptureFailure> {
        guard !isRunning else { return .failure(.alreadyRunning) }
        isRunning = true
        isCancelled = false
        frames = []
        defer { isRunning = false }

        let scrollPoints = max(24, region.height * configuration.scrollRatio)
        var stalledPairs = 0
        var duplicateDrops = 0
        let originalCursor = CGEvent(source: nil)?.location
        defer {
            if let originalCursor {
                CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: originalCursor, mouseButton: .left)?
                    .post(tap: .cghidEventTap)
            }
        }

        for _ in 0..<configuration.maximumFrames {
            if isCancelled { return .failure(.cancelled) }

            let frame: CGImage
            do {
                frame = try await frameProvider(region)
            } catch {
                Log.scroll.error("Scroll capture frame failed: \(error.localizedDescription, privacy: .public)")
                return finishAfterFailure(hasStitchedContent: frames.count > 1, fallbackFailure: .captureFailed)
            }
            frames.append(frame)
            onProgress?(frames.count, nil)
            let frameCount = frames.count
            Log.scroll.debug("Scroll frame \(frameCount, privacy: .public) captured")

            if frames.count >= 2, let offset = stitcher.findOffset(previous: frames[frames.count - 2], next: frame) {
                let capturedOffset = offset
                Log.scroll.debug("Scroll frame \(frameCount, privacy: .public) offset=\(capturedOffset, privacy: .public)")
                if offset <= 0 {
                    // 第一帧后的滚动偶尔会被系统吞掉（窗口刚激活）：丢掉重复帧并重试。
                    if frames.count == 2, duplicateDrops < 3 {
                        duplicateDrops += 1
                        frames.removeLast()
                        Log.scroll.notice("Scroll duplicate frame dropped (retry \(duplicateDrops, privacy: .public))")
                    } else {
                        stalledPairs += 1
                    }
                } else {
                    stalledPairs = 0
                }
                onProgress?(frames.count, offset)
            } else if frames.count >= 2 {
                Log.scroll.debug("Scroll frame \(frameCount, privacy: .public) no overlap")
                stalledPairs += 1
            }

            if stalledPairs >= 2 {
                break
            }

            scrollAction(scrollPoints, scrollLocation)
            let settle = duplicateDrops > 0 && frames.count <= 2
                ? max(configuration.settleMilliseconds, 420)
                : configuration.settleMilliseconds
            await sleep(settle)
        }

        if isCancelled { return .failure(.cancelled) }

        guard frames.count >= 2 else {
            return .failure(accessibilityCheck() ? .noScrollableContent : .accessibilityPermissionRequired)
        }

        let stitched: StitchedImage
        do {
            stitched = try stitcher.stitch(frames: frames)
            Log.scroll.notice("Scroll stitched dims=\(stitched.image.width, privacy: .public)x\(stitched.image.height, privacy: .public) pooledFrames=\(self.frames.count, privacy: .public) stitchedFrames=\(stitched.frameCount, privacy: .public)")
        } catch {
            Log.scroll.error("Scroll stitching failed: \(String(describing: error), privacy: .public)")
            return finishAfterFailure(hasStitchedContent: false, fallbackFailure: .noScrollableContent)
        }

        let minimumHeight = CGFloat(frames[0].height) * configuration.minimumResultHeightRatio
        guard CGFloat(stitched.image.height) >= minimumHeight else {
            return .failure(accessibilityCheck() ? .noScrollableContent : .accessibilityPermissionRequired)
        }

        Log.scroll.notice("Scroll capture stitched \(self.frames.count, privacy: .public) frames -> \(stitched.image.width, privacy: .public)x\(stitched.image.height, privacy: .public) px")
        return .success(stitched.image)
    }

    /// 中途失败时如果已经有足够内容，仍然返回已拼接部分。
    private func finishAfterFailure(hasStitchedContent: Bool, fallbackFailure: ScrollCaptureFailure) -> Result<CGImage, ScrollCaptureFailure> {
        guard hasStitchedContent else { return .failure(fallbackFailure) }
        if let stitched = try? stitcher.stitch(frames: frames),
           stitched.image.height > frames[0].height {
            return .success(stitched.image)
        }
        return .failure(fallbackFailure)
    }

    /// 默认的滚动事件发送。
    ///
    /// 实测（macOS 27）`CGEvent.postToPid` 对 Chrome / 多数 App 不生效，
    /// 因此走 HID tap：先把光标移到目标区域中心，再发送系统级滚轮事件。
    /// 目标 App 在前台（调用方会先激活），滚动就落在它身上。
    static func postScroll(points: CGFloat, location: CGPoint) {
        CGWarpMouseCursorPosition(location)
        let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: location, mouseButton: .left)
        move?.post(tap: .cghidEventTap)
        usleep(20_000)
        let cursor = CGEvent(source: nil)?.location ?? .zero

        guard let source = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(
                scrollWheelEvent2Source: source,
                units: .pixel,
                wheelCount: 1,
                wheel1: Int32(-max(1, Int(points.rounded()))),
                wheel2: 0,
                wheel3: 0
              ) else {
            Log.scroll.error("Failed to create scroll event")
            return
        }
        event.location = location
        event.post(tap: .cghidEventTap)
        Log.scroll.debug("Scroll posted points=\(Int(points), privacy: .public) cursor=\(Int(cursor.x), privacy: .public),\(Int(cursor.y), privacy: .public)")
    }
}
