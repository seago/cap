# 30 · 贴图钉屏

Milestone: M4
Status: done
Blocked by: 29
Type: feature

## Goal

把截图钉成无边框浮窗（NSPanel）：拖动移动、滚轮/按钮缩放、穿透点击开关、Esc 关闭；来源支持编辑器输出、历史条目、剪贴板图片。

## Acceptance

- [x] [auto] `PinnedImageModelTests`：缩放范围 0.1–8x、缩放锚点、窗口尺寸换算
- [x] [auto] build + 既有测试通过
- [x] [manual] ⌘T / 菜单栏「贴到屏幕」把当前编辑结果钉住；拖动、缩放、Esc 关闭正常
- [x] [manual] 可同时钉多张；关掉最后一张退出贴图模式；穿透点击可用
- [x] [manual] 钉屏窗口不出现在截图里（sharingType=.none）

## Scope

In:

- `Cap/Pin/PinnedImageWindow.swift`（borderless NSPanel，`.floating`，sharingType .none）
- `Cap/Pin/PinnedImageController.swift`（多实例管理、缩放、穿透、关闭）
- `Cap/Pin/PinnedImageModel.swift`
- 入口：编辑器工具条「贴图」按钮/⌘T、历史窗口右键「贴到屏幕」
- 全局快捷键显示/隐藏所有贴图（可选）

Out:

- 贴图标注再编辑、贴图分组、跨空间固定（v1.2）

## Runs

### 2026-11-09 21:08 · run 1（实机验收）

- Auto: `PinnedImageModel` 6 项测试（缩放夹取 0.1–8x、显示尺寸、锚点不漂移、中心固定、零尺寸保护）；全量 164 项测试绿
- Manual: 编辑器 ⌘T / 工具条 pin 按钮 → 钉住当前标注结果（600x450）✅
- Manual: 拖动移动窗口（+120,+120 精确跟手）、滚轮以鼠标为锚点缩放（600x450 → 1094x820）、双击回 100%、Esc 关闭 ✅
- Manual: 右键菜单 复制 / 点击穿透 / 关闭 全部可用（复制写回剪贴板 600x450、关闭后窗口消失）✅
- Manual: 多张钉屏同时存在并错开摆放；穿透后鼠标可点到下层窗口 ✅
- Manual: ⌥⌘P 全局切换所有贴图点击穿透（穿透后唯一恢复入口）✅
- Manual: 历史窗口右键「贴到屏幕」直接钉历史截图 ✅
- 修复（本轮暴露）：Carbon 多热键处理器不匹配时必须返回 `eventNotHandledErr`，否则后注册的处理器会吞掉 ⌘⇧2/⌘⇧7；缩放灵敏度按触控板/滚轮分开；`performDrag` 在非激活面板拖动失效 → 改成手动拖窗
- 默认 `sharingType = .none`：钉屏不会出现在截图里
