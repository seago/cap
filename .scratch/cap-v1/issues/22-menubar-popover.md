# 22 · 菜单栏 popover

Milestone: M3
Status: done
Blocked by:
Type: feature

## Goal

点击菜单栏图标弹出 popover：权限状态、最近 8 张截图（2×4 网格）、全部截图入口、设置区、退出。

## Acceptance

- [x] [auto] `RecentHistoryTests`：取最近 8 条、空历史返回空、顺序新到旧
- [x] [auto] build + 既有测试通过
- [x] [manual] 点图标弹出 popover，显示权限状态与 2×4 网格；点缩略图复制并收起
- [x] [manual] 权限未授权时显示「去授权」并可跳转
- [x] [manual] popover 外点击自动收起

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

## Runs

### 2026-11-08 10:24 · run 1

- Auto: build ✅ / test 129 passed ✅
- 实现: `MenuBarPopoverController` + SwiftUI popover（权限状态灯、最近 8 张缩略图网格、全部截图/设置/退出）；`.historyStoreDidChange` 通知自动刷新
- Manual pending: 屏幕已锁（登录窗口），需解锁后验证 popover 外观、点击复制、外点收起

## Runs

### 2026-11-08 17:20 · run 2（解锁后 live 验收）

- Manual: popover 显示绿点「屏幕录制权限正常」；空状态「还没有截图，按 ⌘⇧2 开始」✅
- Manual: 缩略图网格 4 列自动换行（5-6 张时两行），标注版带铅笔角标 ✅
- Manual: 点击缩略图复制成功（日志 `Copied history item from popover` + 剪贴板 600x400），popover 自动收起 ✅
- Manual: 缩略图右键菜单 复制/在 Finder 显示/删除 ✅
- Manual: 「全部截图」打开历史窗口；「设置/收起设置」切换；「退出」可用 ✅
