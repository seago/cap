# 15 · 编辑器数据模型与撤销栈

Milestone: M2
Status: ready-for-agent
Blocked by:
Type: feature

## Goal

把标注、裁剪、撤销/重做、序号计数做成纯模型，不涉及任何视图，可完整单测。

## Acceptance

- [ ] [auto] `EditorSessionTests`：9 种标注（矩形/箭头/直线/文字/画笔/高亮/马赛克/序号/裁剪）的增删与像素坐标存储
- [ ] [auto] 撤销 / 重做：添加 → 撤销 → 重做序列正确；撤销序号后计数回退，再放置序号从正确数字开始
- [ ] [auto] 裁剪一次生效、可撤销，撤销后坐标系恢复
- [ ] [auto] `deleteLast()` 删除最后一条标注
- [ ] [auto] `xcodebuild test` 通过

## Scope

In:

- `Cap/Editor/Annotation.swift`：`Annotation`、`AnnotationKind`、`AnnotationStyle`（红/黄/蓝、线宽 2–12）
- `Cap/Editor/EditorSession.swift`：裁剪、标注数组、undo/redo 栈、序号计数、deleteLast
- `CapTests/EditorSessionTests.swift`

Out:

- 渲染（#16）、窗口与工具条（#17）、鼠标交互（#18）

## Files

- `Cap/Editor/Annotation.swift`
- `Cap/Editor/EditorSession.swift`
- `CapTests/EditorSessionTests.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- 标注坐标一律用原图像素坐标（不是屏幕 point），见 DESIGN §3.4 渲染
- 撤销栈用命令对象，序号计数随命令回滚
