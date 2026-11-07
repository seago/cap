# 10 · 窗口命中与高亮

Milestone: M1
Status: done
Blocked by: 08
Type: feature

## Goal

覆盖层上鼠标悬停到窗口时，高亮该窗口矩形；点击即选中该窗口。

## Acceptance

- [x] [auto] `WindowIndexTests`：从构造的窗口列表里排除自身进程、非 0 层窗口，按 z-order 取最上层命中
- [x] [auto] build + 既有测试通过
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

## Runs

### 2026-11-08 03:38 · run 1

- Auto: build ✅ / test 33 passed ✅（新增 5 个 WindowIndexTests，含真实环境排除自身进程）
- 实现：`WindowIndex` 读取 `CGWindowListCopyWindowInfo`，过滤自身进程 / 非 0 层 / 透明 / 过小；z-order 命中；提供 CG ↔ AppKit 坐标转换
- Manual pending: 悬停高亮与点击选中要等 #09/#13 覆盖层接线后才能验证
