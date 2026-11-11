# 36 · 贴图钉屏：切换窗口后消失 + 缺关闭按钮

Milestone: M6
Status: done
Blocked by:
Type: bugfix

## 反馈

> 贴在屏幕上的截图，不应该切换窗口后没有显示在屏幕上。而且贴屏幕上的截图没有对应的关闭按钮。

## 根因

1. `PinnedImageWindow` 是 `NSPanel`。App 失焦（切到别的窗口/Space/全屏 App）时面板会被系统隐藏，
   钉屏不再参与屏幕合成（`CGWindowListCopyWindowInfo` 的 `onscreen=false`），看起来就是「消失」。
2. 贴图窗口只有 Esc 和右键菜单「关闭」，没有可见的关闭按钮，不易发现。

## 修复

- `PinnedImageWindow.init` 显式 `hidesOnDeactivate = false`；保留 `level = .floating` 与
  `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`。
- `PinnedImageView` 右上角加常驻圆形 `×` 关闭按钮（tooltip/无障碍标签「关闭」），点击走同一条 close 路径。
- 新增 `PinnedImageWindowTests`：`hidesOnDeactivate == false`、floating 层级、跨 Space/全屏 behavior、
  `sharingType == .none`、点击穿透开关。

## 验证

- [x] [auto] 193 项测试通过（新增 2 项）
- [x] [manual] 钉图 → 激活 Finder：钉屏仍在屏幕（`onscreen=true`）✅
- [x] [manual] 钉图 → 切换 Space（Ctrl+→ / Ctrl+1 回来）：仍在 ✅
- [x] [manual] 钉图 → Chrome 正常窗口 / 全屏（Ctrl+Cmd+F）进出：钉屏始终可见 ✅
- [x] [manual] 点击右上角 `×` 关闭钉屏 ✅；Esc / 右键菜单仍可关闭 ✅
