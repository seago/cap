# 24 · 缩略图与 100 张剪枝

Milestone: M3
Status: awaiting-manual
Blocked by: 23
Type: feature

## Goal

历史超过 100 条自动删最旧（连同图片与缩略图）；为网格生成 320px 缩略图。

## Acceptance

- [x] [auto] `HistoryRetentionTests`：插入 105 条后剩 100 条且文件被删；剪枝后索引一致
- [x] [auto] `ThumbnailerTests`：输出 320px 宽 JPEG/RGB，纵横比保持
- [x] [auto] build + 既有测试通过
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

## Runs

### 2026-11-08 10:24 · run 1

- Auto: build ✅ / test 129 passed ✅（105 条插入 → 剩 100 条、最旧 5 条 .png/.jpg 均被删；缩略图 320px 宽、纵横比保持）
- 实现: `Thumbnailer`（320px JPEG）、`HistoryItem.thumbFileName` 向后兼容、`HistoryStore` 剪枝与缩略图补齐
- Manual pending: 解锁后确认真实历史目录出现 thumbs/ 且旧条目在超过 100 后消失
