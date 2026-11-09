# 33 · 设置里增加快捷键设置

Milestone: M4
Status: done
Blocked by:
Type: feature

## Goal

popover 设置区支持录制全局快捷键：截图（默认 ⌘⇧2）、滚动截图（默认 ⌘⇧7）、贴图穿透切换（默认 ⌥⌘P）；持久化到 UserDefaults，修改后立即生效，冲突/被占用时保留原设置并提示。

## Acceptance

- [x] [auto] `HotKeySettingsTests`：默认值、持久化/重载、重置、displayString 生成、无修饰键拒绝、冲突检测
- [x] [auto] build + 既有测试通过
- [x] [manual] 点击「⌘⇧2」按钮进入录制，按下新组合后显示新键并生效（旧键失效）
- [x] [manual] 与其它动作冲突/系统占用时提示且不生效
- [x] [manual] 删除键恢复默认；Esc 取消录制

## Scope

In:

- `Cap/HotKey/HotKeyCenter.swift`：`HotKeyAction`、`HotKeyMapping(keyCode:modifiers:)`、`from(event:)`、`HotKeyCenter.update(mapping:)`
- `Cap/Settings/SettingsStore.swift`：三个动作的快捷键持久化
- `Cap/Settings/ShortcutRecorderView.swift`：SwiftUI 内的按键录制控件（NSButton 子类）
- `Cap/MenuBar/MenuBarPopoverView.swift` / `MenuBarPopoverController.swift`：设置区快捷键行
- `Cap/App/AppDelegate.swift`：按设置注册/重绑热键
- 测试：`CapTests/HotKeySettingsTests.swift`

Out:

- 菜单快捷键、单键快捷键、组合键以外的输入设备

## Runs

### 2026-11-09 21:42 · run 1

- Auto: `HotKeySettingsTests` 8 项（默认值、持久化/重载、重置、冲突检测、displayString、NSEvent→mapping、裸键/仅 Shift 拒绝、allHotKeys）；全量 172 项测试绿
- Manual: 点击 ⌘⇧2 进入录制 → 按下 ⌘⌥J → 按钮与持久化更新、旧 ⌘⇧2 失效、新组合触发截图 ✅
- Manual: 录制中按已占用组合 ⌘⇧7 → 提示「快捷键 ⌘⇧7 已被「滚动截图」占用」，不生效 ✅
- Manual: 录制期间临时注销全局热键（避免按到已有组合触发原功能），结束后自动恢复 ✅
- Manual: ⌫ 恢复默认、Esc 取消录制；滚动截图改 ⌘⌥K 后旧键失效、新键生效，再恢复默认 ⌘⇧7 ✅
- 行内布局：设置区「快捷键」三行（截图/滚动截图/贴图穿透切换），popover 展开时仍锚定菜单栏
