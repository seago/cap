# 07 · 修复「重新启动 Cap」未真正重启

Milestone: M0
Status: ready-for-agent
Blocked by:
Type: fix

## Goal

点击引导窗口的「重新启动 Cap」后，旧进程退出并启动一个新的 Cap 进程，权限状态正确。

## Acceptance

- [ ] [auto] `xcodebuild build` 与 `xcodebuild test` 通过
- [ ] [auto] 单测覆盖 relaunch 请求（可注入 launcher），验证会请求新实例
- [ ] [manual] 点击「重新启动 Cap」后 pid 变化，新进程继续运行
- [ ] [manual] 重启后屏幕录制权限状态正确（已授权则跳过引导）

## Scope

In:

- `Cap/Permissions/ScreenRecordingPermission.swift`：为 `NSWorkspace.OpenConfiguration` 设置 `createsNewApplicationInstance = true`，或改用 `/usr/bin/open -n`
- 若采用可注入 launcher，补单测

Out:

- 权限状态机的其他行为

## Files

- `Cap/Permissions/ScreenRecordingPermission.swift`
- `CapTests/ScreenRecordingPermissionTests.swift`

## Notes

- 2026-11-08 #04 验证时发现：点击后当前进程退出，但没有新进程启动
- 根因疑似 `openApplication` 只激活已有实例，随后 `NSApp.terminate` 把它关掉
