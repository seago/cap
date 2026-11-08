# 19 · 文字工具与中文输入法

Milestone: M2
Status: awaiting-manual
Blocked by: 18
Type: feature

## Goal

文字工具单击定位后就地输入中文/英文，Enter 提交为标注，Esc 取消输入。

## Acceptance

- [x] [auto] `TextAnnotationTests`：提交的文字进入 session，坐标与字号正确；Esc 不产生标注
- [x] [auto] `xcodebuild test` 通过
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

## Runs

### 2026-11-08 09:13 · run 1

- Auto: build ✅ / test 104 passed ✅（新增 4 个文字工具用例：提交/取消/空白/进入 session）
- 实现: `TextEditingController` 叠无边框 NSTextField，Enter 提交、Esc 取消，原生支持中文输入法；提交进入 `EditorSession`
- Manual pending: 屏幕锁定，中文选词上屏与实际输入体验需解锁后补验
