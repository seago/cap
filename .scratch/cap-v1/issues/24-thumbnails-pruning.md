# 24 · 缩略图与 100 张剪枝

Milestone: M3
Status: ready-for-agent
Blocked by: 23
Type: feature

## Goal

历史超过 100 条自动删最旧（连同图片与缩略图）；为网格生成 320px 缩略图。

## Acceptance

- [ ] [auto] `HistoryRetentionTests`：插入 105 条后剩 100 条且文件被删；剪枝后索引一致
- [ ] [auto] `ThumbnailerTests`：输出 320px 宽 JPEG/RGB，纵横比保持
- [ ] [auto] build + 既有测试通过
- [ ] [manual] 历史目录中 thumbs/ 有缩略图；超过 100 张后最旧消失

## Scope

In:

- `Cap/History/Thumbnailer.swift`
- `HistoryStore.append` 生成缩略图；超过 `historyLimit`（默认 100）剪枝
- `HistoryItem` 增加可选 thumbFileName（向后兼容解码）

Out:

- 历史 UI（#23 已完成网格）

## Files

- `Cap/History/Thumbnailer.swift`
- `Cap/History/HistoryStore.swift`
- `Cap/History/HistoryItem.swift`
- `CapTests/HistoryRetentionTests.swift`
- `CapTests/ThumbnailerTests.swift`
- `Cap.xcodeproj/project.pbxproj`
