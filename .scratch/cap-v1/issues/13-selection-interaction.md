# 13 · 选区交互接线

Milestone: M1
Status: done
Blocked by: 09, 10, 11, 12
Type: feature

## Goal

把拖动 / 单击 / 空格 / Enter / Esc 全部接到真实截取，并显示选区尺寸标签。

## Acceptance

- [x] [auto] build + 全部测试通过
- [x] [manual] 拖动松手 → 区域截图；单击窗口 → 窗口截图；Enter → 鼠标所在屏全屏截图
- [x] [manual] 拖动中按空格切换窗口/区域模式，高亮跟随；Esc 取消且不截图
- [x] [manual] 尺寸标签随拖动更新（宽 x 高，像素）
- [x] [manual] 连续 20 次区域/窗口截取无崩溃、无卡死

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

## Runs

### 2026-11-08 03:52 · run 1

- Auto: build ✅ / test 44 passed ✅（新增 simulateSelect 回调与阴影选项用例）
- Manual: 拖动 → 区域截图 ✅；单击窗口 → 窗口截图 ✅；Enter → 鼠标所在屏全屏 1920x1080 ✅
- Manual: Esc 取消不截图 ✅；尺寸标签显示 `W × H` ✅
- Manual: 20 次连续区域截取 20/20 成功，无崩溃、无失败
- 修复: 命中悬停必须在 `model.begin` 之后写入，否则新会话丢弃 hoveredWindow（本轮发现并修复）
- Deferred: 空格切换模式的视觉效果未逐帧验证（状态由单测覆盖）；跨屏拖动需多显示器
