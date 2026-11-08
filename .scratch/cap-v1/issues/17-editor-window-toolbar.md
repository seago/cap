# 17 · 编辑器窗口与工具条

Milestone: M2
Status: ready-for-agent
Blocked by: 16
Type: feature

## Goal

截图后选区内冻结出编辑面板，下方 8pt 浮出工具条；空间不足时翻到上方，再不足时贴屏幕内。

## Acceptance

- [ ] [auto] 工具条定位纯函数单测：下方够 → 下方；下方不够 → 上方；都不够 → 夹到可见区域
- [ ] [auto] `xcodebuild test` 通过
- [ ] [manual] 截图后出现冻结面板（周围屏幕保持实时），工具条在面板外且不覆盖面板
- [ ] [manual] 选区贴屏幕底部时工具条翻到上方；贴角时仍在可见区域
- [ ] [manual] 工具条不抢焦点（点击工具不导致面板失焦/消失）

## Scope

In:

- `Cap/Editor/EditorController.swift`、`EditorPanelWindow.swift`、`EditorToolbarWindow.swift`
- 工具条按钮：关闭/裁剪/矩形/箭头/直线/文字/画笔/高亮/马赛克/序号/撤销/重做/颜色/线宽/完成/保存
- 冻结底图显示
- AppDelegate 接线：截图成功后进入编辑器（而不是直接结束）

Out:

- 画布绘制交互（#18）、文字输入（#19）、输出（#20）

## Files

- `Cap/Editor/EditorController.swift`
- `Cap/Editor/EditorPanelWindow.swift`
- `Cap/Editor/EditorToolbarWindow.swift`
- `Cap/Editor/ToolbarLayout.swift`
- `Cap/App/AppDelegate.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- 面板窗口 `sharingType = .none`，层级低于覆盖层但高于普通窗口
- 工具条为独立窗口，`canBecomeKey = false` 避免抢焦点（文字工具另行处理）
