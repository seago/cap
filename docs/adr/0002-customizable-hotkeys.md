# ADR 0002 · 可录制的全局快捷键

- 状态：已采纳（2026-11-09）
- 相关：`.scratch/cap-v1/issues/33-hotkey-settings.md`、`DESIGN.md` §4.5

## 背景

v1 固定 ⌘⇧2；v1.1 用户要求设置里可改快捷键。需要考虑：录制交互、持久化、冲突、以及 Carbon 的特殊行为。

## 决策

- 定义 `HotKeyAction`（截图 / 滚动长截图 / 贴图穿透切换），每个动作一个 `HotKeyCenter`（Carbon `RegisterEventHotKey` + `InstallEventHandler`），identifier 区分。
- `HotKeyMapping(keyCode:modifiers:)` 保存 Carbon keyCode + modifiers，显示字符串由两者生成；持久化到 UserDefaults 的 `hotKey.<action>.keyCode/.modifiers`。
- 设置区用 AppKit 的 `ShortcutRecorderButton`（SwiftUI `NSViewRepresentable`）：点击进入录制、⌫ 恢复默认、Esc 取消；要求至少一个 ⌘/⌥/⌃。
- **录制期间临时注销所有全局热键**，结束后按当前设置统一重注册；否则按到已有组合会直接触发原功能。
- 修改只在新组合注册成功后才写设置；与其它动作冲突/被系统占用时提示并保留原设置。

## 后果

- ✅ 三个动作可独立改键，立即生效并持久化。
- ⚠️ Carbon 不报跨进程冲突（头文件明确同一组合多进程注册不算错误），只能实测发现；提示语言为「被系统或其它 App 占用」。
- ⚠️ 多个 `HotKeyCenter` 实例共存时，事件处理器不匹配必须返回 `eventNotHandledErr`，否则会吞掉其它热键事件——已在 `HotKeyCenter` 注释中记录。
