# 22 · 菜单栏 popover

Milestone: M3
Status: ready-for-agent
Blocked by:
Type: feature

## Goal

点击菜单栏图标弹出 popover：权限状态、最近 8 张截图（2×4 网格）、全部截图入口、设置区、退出。

## Acceptance

- [ ] [auto] `RecentHistoryTests`：取最近 8 条、空历史返回空、顺序新到旧
- [ ] [auto] build + 既有测试通过
- [ ] [manual] 点图标弹出 popover，显示权限状态与 2×4 网格；点缩略图复制并收起
- [ ] [manual] 权限未授权时显示「去授权」并可跳转
- [ ] [manual] popover 外点击自动收起

## Scope

In:

- `Cap/MenuBar/MenuBarPopoverController.swift`、`MenuBarPopoverView.swift`
- HistoryStore 暴露最近记录读取
- 退出、全部截图（打开历史窗口）、设置入口

Out:

- 历史窗口本体（#23）、设置项实现（#25）

## Files

- `Cap/MenuBar/MenuBarPopoverController.swift`
- `Cap/MenuBar/MenuBarPopoverView.swift`
- `Cap/MenuBar/MenuBarController.swift`
- `CapTests/RecentHistoryTests.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- `NSPopover` + NSStatusItem button；不抢焦点
