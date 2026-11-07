# 02 · 全局快捷键 ⌘⇧2

Milestone: M0
Status: done
Blocked by: 01
Type: feature

## Goal

在任何 App 前台按 ⌘⇧2 都能触发 Cap 的动作；M0 先触发一个可观察的回调（日志/菜单项），不接截图。

## Acceptance

- [x] [auto] `HotKeyMapping` 单测：⌘⇧2 → keyCode / modifiers 映射正确；重复 register / unregister 不崩溃
- [x] [auto] `xcodebuild test -project Cap.xcodeproj -scheme Cap -destination 'platform=macOS'` 通过，原有用例不回归
- [x] [manual] 在 Finder / Safari 前台按 ⌘⇧2，菜单栏图标有反馈或日志出现；连续按 20 次稳定

## Scope

In:

- `Cap/HotKey/HotKeyCenter.swift`（Carbon `RegisterEventHotKey` 封装）
- 固定 ⌘⇧2；`SettingsStore` 先不引入
- AppDelegate 接线：注册、注销、回调
- 单测用可注入的 registrar 或纯映射类型

Out:

- 录制快捷键 UI、冲突警告、用户改键
- 截图触发（#04）

## Files

- `Cap/HotKey/HotKeyCenter.swift`
- `Cap/App/AppDelegate.swift`（接线）
- `CapTests/HotKeyTests.swift`

## Notes

- Carbon 的 `RegisterEventHotKey` 在 Swift 6 下注意 `@MainActor` / C 回调边界
- 注册失败（被占用 / 参数错）要 log，不崩溃

## Runs

### 2026-11-08 02:48 · run 1

- Auto: build ✅ / test 3 passed ✅ / HotKeyMapping ✅ / register + unregister 幂等 ✅
- Manual: Finder 前台合成 ⌘⇧2 → `Global hotkey triggered` + `⌘⇧2 action fired`；连续 20 次 20/20，进程存活
- Evidence: `log show --predicate 'subsystem == "dev.bruce.cap"'`（02:47:36、02:48）
