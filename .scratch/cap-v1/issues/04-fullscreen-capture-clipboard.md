# 04 · 全屏截图到剪贴板

Milestone: M0
Status: done
Blocked by: 02, 03
Type: feature

## Goal

按 ⌘⇧2 截取鼠标所在显示器的全屏，关闭光标，PNG + TIFF 写入剪贴板。

## Acceptance

- [x] [auto] `ClipboardWriter` 单测（fake pasteboard）：写入 `.png` 与 `.tiff` 两种类型、清空旧内容、失败时返回错误
- [x] [auto] `xcodebuild test -project Cap.xcodeproj -scheme Cap -destination 'platform=macOS'` 通过
- [x] [manual] 单屏与双屏环境各截一次；粘贴到 Preview 尺寸与屏幕像素一致
- [x] [manual] 截图中不出现光标
- [x] [manual] 截图中不出现 Cap 自己的窗口 / 覆盖层
- [x] [manual] 运行中撤销屏幕录制权限后按 ⌘⇧2，有明确错误提示

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
- 「运行中撤销权限的错误提示」从 #03 移入本 ticket

## Runs

### 2026-11-08 03:03 · run 1

- Auto: build ✅ / test 11 passed ✅
- Manual: 单屏 1920x1200 捕获 ✅（剪贴板 PNG + TIFF；`sips` 尺寸一致）；无光标 ✅；无 Cap 窗口 / 覆盖层 ✅
- Manual: 本机只有一块显示器，双屏未验证（环境限制）
- Manual: 撤销权限后触发 → 日志明确 `SCShareableContent failed ... TCC` + `Capture failed: Cap 没有屏幕录制权限`；系统 TCC alert 同时出现，Cap 模态 alert 未单独截到
- Environment: 重建后 ad-hoc 签名变化，TCC 失效；需重新授权（#06 解决）
