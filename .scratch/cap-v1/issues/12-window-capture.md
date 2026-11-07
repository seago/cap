# 12 · 窗口截取

Milestone: M1
Status: ready-for-agent
Blocked by: 10
Type: feature

## Goal

单击窗口时截取该窗口（默认带阴影/圆角），按住 Option 单击则不带阴影。

## Acceptance

- [ ] [auto] build + 既有测试通过
- [ ] [auto] 阴影配置：默认 `ignoreShadowsSingleWindow = false`，Option 时为 true（可单测配置构造）
- [ ] [manual] 单击 Safari 窗口 → 剪贴板图片为该窗口，带阴影、无灰罩、无 Cap UI
- [ ] [manual] Option 单击同一窗口 → 图片无阴影

## Scope

In:

- `CaptureSource.window(CGWindowID)` → `SCContentFilter(desktopIndependentWindow:)`
- Option 修饰键读取
- 成功后写剪贴板 + 历史

Out:

- 多窗口拼接、滚动长截图

## Files

- `Cap/Capture/ScreenCaptureService.swift`
- `CapTests/ScreenCaptureConfigurationTests.swift`
- `Cap/Selection/SelectionOverlayController.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- 最小化窗口可能截不到，需错误处理
