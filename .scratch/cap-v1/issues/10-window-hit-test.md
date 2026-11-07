# 10 · 窗口命中与高亮

Milestone: M1
Status: ready-for-agent
Blocked by: 08
Type: feature

## Goal

覆盖层上鼠标悬停到窗口时，高亮该窗口矩形；点击即选中该窗口。

## Acceptance

- [ ] [auto] `WindowIndexTests`：从构造的窗口列表里排除自身进程、非 0 层窗口，按 z-order 取最上层命中
- [ ] [auto] build + 既有测试通过
- [ ] [manual] 悬停 Safari / Finder / 菜单栏 App 分别高亮对应窗口，矩形贴合窗口边界
- [ ] [manual] 点击高亮的窗口后，选中目标为该窗口（日志或后续截图验证）

## Scope

In:

- `Cap/Capture/WindowIndex.swift`：`CGWindowListCopyWindowInfo` 读取、z-order、排除自身
- 覆盖层接收悬停 → 高亮矩形
- 单击 → `window(CGWindowID)` 目标

Out:

- 窗口截图（#12）

## Files

- `Cap/Capture/WindowIndex.swift`
- `CapTests/WindowIndexTests.swift`
- `Cap/Selection/SelectionOverlayController.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- 排除规则：ownerPID == 自己、layer != 0、alpha == 0、尺寸过小
- 命中顺序用列表顺序（顶层在前）
