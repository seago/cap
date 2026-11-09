# 30 · 贴图钉屏

Milestone: M4
Status: ready-for-agent
Blocked by: 29
Type: feature

## Goal

把截图钉成无边框浮窗（NSPanel）：拖动移动、滚轮/按钮缩放、穿透点击开关、Esc 关闭；来源支持编辑器输出、历史条目、剪贴板图片。

## Acceptance

- [ ] [auto] `PinnedImageModelTests`：缩放范围 0.1–8x、缩放锚点、窗口尺寸换算
- [ ] [auto] build + 既有测试通过
- [ ] [manual] ⌘T / 菜单栏「贴到屏幕」把当前编辑结果钉住；拖动、缩放、Esc 关闭正常
- [ ] [manual] 可同时钉多张；关掉最后一张退出贴图模式；穿透点击可用
- [ ] [manual] 钉屏窗口不出现在截图里（sharingType=.none）

## Scope

In:

- `Cap/Pin/PinnedImageWindow.swift`（borderless NSPanel，`.floating`，sharingType .none）
- `Cap/Pin/PinnedImageController.swift`（多实例管理、缩放、穿透、关闭）
- `Cap/Pin/PinnedImageModel.swift`
- 入口：编辑器工具条「贴图」按钮/⌘T、历史窗口右键「贴到屏幕」
- 全局快捷键显示/隐藏所有贴图（可选）

Out:

- 贴图标注再编辑、贴图分组、跨空间固定（v1.2）
