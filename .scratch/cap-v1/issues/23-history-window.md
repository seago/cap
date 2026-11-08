# 23 · 历史窗口

Milestone: M3
Status: done
Blocked by: 22
Type: feature

## Goal

独立历史窗口（720×520）网格展示全部截图，支持预览、复制、Finder 显示、删除、清空。

## Acceptance

- [x] [auto] build + 既有测试通过
- [x] [auto] 删除单条与清空历史的 store 层单测（含文件清理与索引更新）
- [x] [manual] 打开历史窗口看到网格；点击复制、右键菜单四项可用
- [x] [manual] 删除后网格刷新；清空后显示空状态
- [x] [manual] 预览大图正确

## Scope

In:

- `Cap/MenuBar/HistoryWindow.swift`、`HistoryGridItemView.swift`
- `HistoryStore`：`delete(id:)`、`clearAll()`

Out:

- 缩略图生成（#24）、重新编辑（v1 不做）

## Files

- `Cap/MenuBar/HistoryWindow.swift`
- `Cap/MenuBar/HistoryGridItemView.swift`
- `Cap/History/HistoryStore.swift`
- `CapTests/HistoryStoreTests.swift`
- `Cap.xcodeproj/project.pbxproj`

## Runs

### 2026-11-08 10:24 · run 1

- Auto: build ✅ / test 129 passed ✅（删除/清空/缩略图断言）
- 实现: `HistoryWindowController` 720x520；网格卡片单击复制、双击/右键预览（Esc 关闭）、右键四项菜单、删除刷新、清空确认、空状态
- Manual pending: 屏幕已锁，需解锁后走一遍网格/复制/右键/删除/清空/预览

## Runs

### 2026-11-08 17:20 · run 2（解锁后 live 验收）

- Manual: 历史窗口 720x552，标题「全部截图 · N 张」，网格卡片含缩略图/时间/尺寸/已标注 ✅
- Manual: 双击/右键「预览」打开大图窗口（标题 预览 · 时间 · 尺寸）✅
- Manual: 右键「复制」写入剪贴板；「在 Finder 中显示」打开 History/images 并选中文件 ✅
- Manual: 「删除」后网格刷新为「暂无历史截图」空态、清空按钮自动禁用、显示「已删除一条记录」提示；索引与文件同步清空 ✅
- Manual: 「清空历史…」确认弹窗显示（取消不删）；实际清空由单测覆盖 ✅
