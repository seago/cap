# 13 · 选区交互接线

Milestone: M1
Status: ready-for-agent
Blocked by: 09, 10, 11, 12
Type: feature

## Goal

把拖动 / 单击 / 空格 / Enter / Esc 全部接到真实截取，并显示选区尺寸标签。

## Acceptance

- [ ] [auto] build + 全部测试通过
- [ ] [manual] 拖动松手 → 区域截图；单击窗口 → 窗口截图；Enter → 鼠标所在屏全屏截图
- [ ] [manual] 拖动中按空格切换窗口/区域模式，高亮跟随；Esc 取消且不截图
- [ ] [manual] 尺寸标签随拖动更新（宽 x 高，像素）
- [ ] [manual] 连续 20 次区域/窗口截取无崩溃、无卡死

## Scope

In:

- `SelectionModel` 事件接入覆盖层（鼠标、键盘）
- 尺寸标签绘制
- 三种目标统一走剪贴板 + 历史
- 取消路径清理

Out:

- 编辑器（M2）

## Files

- `Cap/Selection/SelectionOverlayController.swift`
- `Cap/Selection/SelectionCanvasView.swift`
- `Cap/App/AppDelegate.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- 单屏环境：跨屏拖动记 `Deferred`
