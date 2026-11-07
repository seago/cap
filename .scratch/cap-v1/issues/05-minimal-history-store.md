# 05 · 最小历史存储

Milestone: M0
Status: ready-for-agent
Blocked by: 04
Type: feature

## Goal

每次截图把 PNG 写入 `~/Library/Application Support/Cap/History/images/`，并在 `index.json` 记录一条；重启 App 后能读回。

## Acceptance

- [ ] [auto] `HistoryStore` 单测：append → load 回同一条；索引原子写（临时文件 + rename）；索引损坏时从 `images/` 重建
- [ ] [auto] 图片文件写入 `images/{uuid}.png`，PNG 可解码
- [ ] [auto] `xcodebuild test -project Cap.xcodeproj -scheme Cap -destination 'platform=macOS'` 通过
- [ ] [manual] 截图后 History 目录出现 `index.json` 与一张 PNG
- [ ] [manual] 退出并重启 App，历史仍能读到（日志或调试输出即可）

## Scope

In:

- `Cap/History/HistoryItem.swift`、`Cap/History/HistoryStore.swift`
- 目录创建、原子索引写、启动加载 / 重建
- 截图成功后插入原图记录

Out:

- 缩略图、100 条剪枝、历史窗口、标注版替换（M3）
- 历史 UI

## Files

- `Cap/History/HistoryItem.swift`
- `Cap/History/HistoryStore.swift`
- `Cap/App/AppDelegate.swift`
- `CapTests/HistoryStoreTests.swift`

## Notes

- 目录与字段按 `DESIGN.md` §6.1
- 本 milestone 只保证「先存一张」可用；剪枝和缩略图留给 M3
