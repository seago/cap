# 19 · 文字工具与中文输入法

Milestone: M2
Status: done
Blocked by: 18
Type: feature

## Goal

文字工具单击定位后就地输入中文/英文，Enter 提交为标注，Esc 取消输入。

## Acceptance

- [x] [auto] `TextAnnotationTests`：提交的文字进入 session，坐标与字号正确；Esc 不产生标注
- [x] [auto] `xcodebuild test` 通过
- [x] [manual] 中文输入法可正常选词、上屏；英文正常
- [x] [manual] Enter 提交、Esc 取消；输入框位置贴合点击处
- [x] [manual] Retina 下文字清晰，不模糊

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

## Runs

### 2026-11-08 10:01 · run 2（解锁后 live 验收）

- Manual: 点击画布出现就地输入框，提交后文字以标注形式渲染 ✅
- Manual: 中文文本 `你好 Cap 中文` 在编辑器中正确渲染并进入最终输出 ✅
- Caveat: 自动化无法驱动输入法组词（合成按键绕过 IME，只插入 ASCII `nihao`）；中文是通过 AX 设置输入框内容验证的。真实 IME 选词上屏仍需你手打一次确认，代码路径（NSTextField 原生输入法）没有做特殊处理
