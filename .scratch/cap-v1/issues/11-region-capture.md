# 11 · 区域截取

Milestone: M1
Status: ready-for-agent
Blocked by: 09
Type: feature

## Goal

拖动选区松手后，用跨屏矩形截取图像，写入剪贴板与历史。

## Acceptance

- [ ] [auto] `ScreenCaptureService` 单测：区域矩形换算像素尺寸（scale）正确；空矩形抛错
- [ ] [auto] build + 既有测试通过
- [ ] [manual] 拖动选区松手 → 剪贴板拿到对应区域 PNG，尺寸为所选区域像素
- [ ] [manual] 截图不含压暗覆盖层（`sharingType = .none` 生效）
- [ ] [manual] 选区可任意方向拖动、1px 精度可复现

## Scope

In:

- `CaptureSource.region(CGRect)` → `SCScreenshotManager.captureImage(in:)`（macOS 15.2+）
- 松手触发截取；成功后写剪贴板 + 历史（复用 M0 链路）
- 截取失败错误路径

Out:

- 窗口截取（#12）
- 全屏（已有 #04）

## Files

- `Cap/Capture/ScreenCaptureService.swift`
- `Cap/Selection/SelectionOverlayController.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- 全局 point 矩形需按屏幕 scale 转像素；跨屏只覆盖本机单屏时按该屏 scale
- 覆盖层关闭后再截图，避免灰罩进图
