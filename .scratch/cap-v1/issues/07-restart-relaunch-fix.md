# 07 · 修复「重新启动 Cap」未真正重启

Milestone: M0
Status: done
Blocked by:
Type: fix

## Goal

点击引导窗口的「重新启动 Cap」后，旧进程退出并启动一个新的 Cap 进程，权限状态正确。

## Acceptance

- [x] [auto] `xcodebuild build` 与 `xcodebuild test` 通过
- [x] [auto] 单测覆盖 relaunch 请求（可注入 launcher），验证会请求新实例
- [x] [manual] 点击「重新启动 Cap」后 pid 变化，新进程继续运行
- [x] [manual] 重启后屏幕录制权限状态正确（已授权则跳过引导）

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

## Runs

### 2026-11-08 03:29 · run 1

- Auto: build ✅ / test 19 passed ✅（新增 `relaunchRequestsNewApplicationInstance`）
- Root cause: `openApplication` 在旧实例运行时命中已有实例并返回它，随后 `NSApp.terminate` 把唯一实例关掉
- Fix: `ScreenRecordingRelaunch.makeConfiguration()` 设置 `createsNewApplicationInstance = true`；`relaunch()` 复用该工厂
- Manual: 负向对照（旧默认配置）→ 返回已有 pid，无新进程 ✅ 复现原缺陷
- Manual: 真实「重新启动 Cap」按钮路径 → 旧 pid 7119 `terminating` → 新 pid 7147 `launched`，新进程存活 ✅
- Manual: 已授权状态下重启 → `Screen recording permission: true`，引导跳过 ✅
- Residual: `openApplication` 返回错误时仍会 terminate（未观测到）；单测只覆盖工厂配置，未断言 `relaunch()` 注入
