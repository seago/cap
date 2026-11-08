# 19 · 文字工具与中文输入法

Milestone: M2
Status: ready-for-agent
Blocked by: 18
Type: feature

## Goal

文字工具单击定位后就地输入中文/英文，Enter 提交为标注，Esc 取消输入。

## Acceptance

- [ ] [auto] `TextAnnotationTests`：提交的文字进入 session，坐标与字号正确；Esc 不产生标注
- [ ] [auto] `xcodebuild test` 通过
- [ ] [manual] 中文输入法可正常选词、上屏；英文正常
- [ ] [manual] Enter 提交、Esc 取消；输入框位置贴合点击处
- [ ] [manual] Retina 下文字清晰，不模糊

## Scope

In:

- `Cap/Editor/TextEditingController.swift`
- 临时 `NSTextField` / `NSTextView` 叠层，Enter/Esc 处理
- 输入期间面板临时可成为 key window

Out:

- 字体选择、字号调节（v1 不做）

## Files

- `Cap/Editor/TextEditingController.swift`
- `Cap/Editor/EditorController.swift`
- `CapTests/TextAnnotationTests.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- DESIGN §9 风险 #4：非激活面板无法输入文字；必要时临时 `makeKey`
