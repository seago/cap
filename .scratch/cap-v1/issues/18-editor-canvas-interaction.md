# 18 · 画布交互与工具绘制

Milestone: M2
Status: awaiting-manual
Blocked by: 15, 16, 17
Type: feature

## Goal

在冻结面板上真正画出标注：拖拽类工具、单击类工具、裁剪、删除、撤销重做快捷键。

## Acceptance

- [x] [auto] `EditorCanvasTests`：鼠标按下/拖动/抬起换算为图像像素坐标；工具产生正确 Annotation
- [x] [auto] `xcodebuild test` 通过
- [ ] [manual] 矩形/箭头/直线/画笔/高亮/马赛克 拖拽绘制正常，多笔画连续
- [ ] [manual] 序号单击放置并按 1,2,3 递增；删除键删最后一条
- [ ] [manual] 裁剪拖框松手生效，可撤销
- [ ] [manual] ⌘Z / ⇧⌘Z 撤销重做 ≥10 步

## Scope

In:

- `Cap/Editor/EditorCanvasView.swift`：坐标换算 + 实时预览
- 工具绘制逻辑（拖拽/单击）
- 趋势：像素坐标缩放（view point ↔ image pixel）
- 快捷键：⌘Z、⇧⌘Z、delete

Out:

- 文字输入（#19）、输出（#20）

## Files

- `Cap/Editor/EditorCanvasView.swift`
- `Cap/Editor/CanvasGeometry.swift`
- `CapTests/EditorCanvasTests.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- 坐标系按 DESIGN §4.4；测试用纯函数换算，避免依赖真实窗口

## Runs

### 2026-11-08 09:13 · run 1

- Auto: build ✅ / test 104 passed ✅（新增 CanvasGeometry 7 + 画布草稿 4 组断言）
- 实现: `CanvasGeometry`（视图点 ↔ 图像像素、任意方向归一化）、`AnnotationDraft`（各工具草稿 + 1px 最小尺寸）、画布 mouseDown/Dragged/Up 与实时预览
- Manual pending: 屏幕锁定（`CGSSessionScreenIsLocked=1`）导致合成鼠标无法到达，解锁后补验拖拽绘制/序号/裁剪/⌘Z 10 步
