# 04 · 全屏截图到剪贴板

Milestone: M0
Status: ready-for-agent
Blocked by: 02, 03
Type: feature

## Goal

按 ⌘⇧2 截取鼠标所在显示器的全屏，关闭光标，PNG + TIFF 写入剪贴板。

## Acceptance

- [ ] [auto] `ClipboardWriter` 单测（fake pasteboard）：写入 `.png` 与 `.tiff` 两种类型、清空旧内容、失败时返回错误
- [ ] [auto] `xcodebuild test -project Cap.xcodeproj -scheme Cap -destination 'platform=macOS'` 通过
- [ ] [manual] 单屏与双屏环境各截一次；粘贴到 Preview 尺寸与屏幕像素一致
- [ ] [manual] 截图中不出现光标
- [ ] [manual] 截图中不出现 Cap 自己的窗口 / 覆盖层

## Scope

In:

- `Cap/Capture/CaptureRequest.swift`、`Cap/Capture/ScreenCaptureService.swift`（display 来源）
- 鼠标所在屏幕判定（`NSScreen.screens` + `NSEvent.mouseLocation`）
- `SCScreenshotManager.captureImage(contentFilter:configuration:)`；`showsCursor = false`
- `Cap/Output/ClipboardWriter.swift`、`Cap/Output/ImageEncoder.swift`
- 快捷键回调接截图
- 失败路径：权限缺失 / 截取失败 → 日志 + 用户可见提示（简单 alert 即可）

Out:

- 区域、窗口选择
- 编辑器、历史写入（#05）
- 保存文件

## Files

- `Cap/Capture/CaptureRequest.swift`
- `Cap/Capture/ScreenCaptureService.swift`
- `Cap/Output/ClipboardWriter.swift`
- `Cap/Output/ImageEncoder.swift`
- `Cap/App/AppDelegate.swift`
- `CapTests/ClipboardWriterTests.swift`

## Notes

- 目标 macOS 15.2，直接用 `SCScreenshotManager`
- 自身窗口 `sharingType = .none`；M0 没有覆盖层，先用菜单栏 App 验证
- 配置的 width / height 用 display 的像素尺寸，避免 Retina 缩水
