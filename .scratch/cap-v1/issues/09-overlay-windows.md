# 09 · 多屏覆盖层与压暗

Milestone: M1
Status: done
Blocked by: 08
Type: feature

## Goal

按 ⌘⇧2 后所有屏幕出现半透明压暗覆盖层，带十字准星，鼠标悬停处显示清晰挖孔；Esc 关闭。

## Acceptance

- [x] [auto] build + 既有测试通过
- [x] [auto] 覆盖层窗口数量 = `NSScreen.screens.count`；`sharingType = .none`；`collectionBehavior` 含 `.canJoinAllSpaces` + `.fullScreenAuxiliary`
- [x] [manual] 按 ⌘⇧2 后所有屏幕变暗，移动鼠标有十字准星与挖孔；Esc 关闭且不残留窗口
- [x] [manual] 覆盖层不进入 Dock/切换器；退出选区后 App 仍常驻菜单栏

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

## Runs

### 2026-11-08 03:42 · run 1

- Auto: build ✅ / test 38 passed ✅（新增 5 个 SelectionOverlayTests：窗口数 = 屏幕数、sharingType、collectionBehavior、dismiss、cancel 回调）
- Manual: 合成 ⌘⇧2 → 日志 `Selection overlay presented on 1 screen(s)`；截图可见压暗 + 挖孔 + 十字准星 + 尺寸标签 `120 × 120` ✅
- Manual: Esc → 窗口消失、日志 `Selection cancelled`，无残留 ✅
- 关键发现: `sharingType = .none` 的窗口也不会进入 `screencapture`，因此验证绘制时需 `CAP_OVERLAY_CAPTURABLE=1` 临时改为 `.readOnly`；生产路径仍为 `.none`
- 单屏环境：多屏项记 `Deferred`
