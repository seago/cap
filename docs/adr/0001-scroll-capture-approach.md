# ADR 0001 · 滚动长截图的实现路线

- 状态：已采纳（2026-11-09）
- 相关：`.scratch/cap-v1/issues/28-scroll-capture-spike.md`

## 背景

需要「对可滚动页面自动生成一张长截图」。候选路线：

1. Accessibility API 驱动滚动 + 逐帧截图 + 特征匹配拼接
2. 纯注入滚动事件（HID）+ 逐帧截图拼接
3. `SCStream` 持续录屏 + 离线拼接

## 决策

采用 **框选区域 → AXRaise 目标窗口 → HID 滚轮事件自动滚动 → 逐帧截图 → 特征匹配拼接**。

关键实现：

- 拼接用 `ScrollStitcher`：RGBA8 解码 → vDSP 行特征一维滑动找候选 → 稀疏二维校验 → 全分辨率逐通道差确认 + 歧义保护。
- 滚动事件必须走 HID tap（`CGEvent.post(tap: .cghidEventTap)`）+ 光标 warp；`CGEvent.postToPid` 对 Chrome 无效。
- 滚动前用 AXRaise 把目标窗口提到前台（用户正在操作其它 App 时 `NSRunningApplication.activate` 会被忽略）。
- 第一帧滚动可能被系统吞掉：丢弃重复帧重试，最多 3 次。
- 上限 12 帧，Esc 中止（目标 App 前台时用全局 key monitor）。

## 后果

- ✅ Chrome 长页实测 1100×2625 内容连续、无错误拼接；拼接算法像素级正确。
- ⚠️ 需要「辅助功能」权限（macOS 27 上授予需要管理员密码）。
- ⚠️ 吸顶导航/动态内容可能导致提前停止；拼接器宁可停止也不输出错位图。
- ⚠️ 不做横向滚动拼接、无限加载页面。
