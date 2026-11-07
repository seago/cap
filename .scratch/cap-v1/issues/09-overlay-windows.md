# 09 · 多屏覆盖层与压暗

Milestone: M1
Status: ready-for-agent
Blocked by: 08
Type: feature

## Goal

按 ⌘⇧2 后所有屏幕出现半透明压暗覆盖层，带十字准星，鼠标悬停处显示清晰挖孔；Esc 关闭。

## Acceptance

- [ ] [auto] build + 既有测试通过
- [ ] [auto] 覆盖层窗口数量 = `NSScreen.screens.count`；`sharingType = .none`；`collectionBehavior` 含 `.canJoinAllSpaces` + `.fullScreenAuxiliary`
- [ ] [manual] 按 ⌘⇧2 后所有屏幕变暗，移动鼠标有十字准星与挖孔；Esc 关闭且不残留窗口
- [ ] [manual] 覆盖层不进入 Dock/切换器；退出选区后 App 仍常驻菜单栏

## Scope

In:

- `Cap/Selection/SelectionOverlayController.swift`、`SelectionOverlayWindow.swift`、`SelectionCanvasView.swift`
- 压暗绘制、挖孔、十字准星、尺寸标签占位
- AppDelegate 接线：⌘⇧2 → 打开覆盖层；Esc → 关闭
- 覆盖层 `sharingType = .none`

Out:

- 窗口高亮与命中（#10）
- 截图（#11/#12）
- 工具条

## Files

- `Cap/Selection/SelectionOverlayController.swift`
- `Cap/Selection/SelectionOverlayWindow.swift`
- `Cap/Selection/SelectionCanvasView.swift`
- `Cap/App/AppDelegate.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- 覆盖层窗口：`NSWindow` borderless、`.screenSaver` 层或 `.mainMenu + 1`（实测确定）
- 多屏环境不具备时，跨屏项记 `Deferred`
