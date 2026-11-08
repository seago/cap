# 23 · 历史窗口

Milestone: M3
Status: ready-for-agent
Blocked by: 22
Type: feature

## Goal

独立历史窗口（720×520）网格展示全部截图，支持预览、复制、Finder 显示、删除、清空。

## Acceptance

- [ ] [auto] build + 既有测试通过
- [ ] [auto] 删除单条与清空历史的 store 层单测（含文件清理与索引更新）
- [ ] [manual] 打开历史窗口看到网格；点击复制、右键菜单四项可用
- [ ] [manual] 删除后网格刷新；清空后显示空状态
- [ ] [manual] 预览大图正确

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
