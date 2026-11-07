# 08 · 选区状态模型

Milestone: M1
Status: done
Blocked by:
Type: feature

## Goal

把「拖动 = 区域、单击 = 窗口、空格 = 切换、Enter = 鼠标所在屏全屏、Esc = 取消、3pt 阈值」做成可单测的纯状态模型，不涉及 UI。

## Acceptance

- [x] [auto] `SelectionStateTests`：按下→移动→抬起生成 `region`；位移 < 3pt 视为单击（`window`）
- [x] [auto] 空格在拖动中切换 region/window 模式；Esc 重置为 idle；Enter 在未拖动时给出鼠标所在屏的 `display` 目标
- [x] [auto] 区域矩形归一化：任意方向拖拽都得到正矩形；跨屏坐标为全局坐标
- [x] [auto] `xcodebuild test` 通过
- [x] [manual] 无 UI 依赖，由单测与后续 ticket 联调验证

## Scope

In:

- `Cap/Selection/SelectionModel.swift`：`SelectionMode`、`SelectionSession`、事件输入方法
- `CapTests/SelectionStateTests.swift`
- pbxproj 登记

Out:

- 覆盖层窗口、绘制、光标（#09）
- 截图（#11/#12）

## Files

- `Cap/Selection/SelectionModel.swift`
- `CapTests/SelectionStateTests.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- 坐标：全局屏幕坐标（points），`NSScreen.screens` 多屏时原点是主屏左上
- 阈值 3pt 来自 DESIGN §3.2
- 状态模型不引用 AppKit UI 类型，只依赖 CGRect/CGPoint

## Runs

### 2026-11-08 03:40 · run 1

- Auto: build ✅ / test 28 passed ✅（新增 9 个 SelectionStateTests）
- Manual: 纯状态模型，由单测覆盖；UI 联调在 #13
- 实现细节：`SelectionModel` 只依赖 CoreGraphics；3pt 阈值；任意方向归一化；Enter 在拖动中不触发全屏
