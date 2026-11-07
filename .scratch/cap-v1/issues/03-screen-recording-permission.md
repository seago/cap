# 03 · 屏幕录制权限引导

Milestone: M0
Status: done
Blocked by: 01
Type: feature

## Goal

首次启动引导用户授予屏幕录制权限；覆盖已授权、被拒绝、运行中撤销、需要重启进程四种状态。

## Acceptance

- [x] [auto] 权限状态机单测：未决定 / 已授权 / 已拒绝 / 需重启 → 对应动作（fake preflight / request）
- [x] [auto] `xcodebuild test -project Cap.xcodeproj -scheme Cap -destination 'platform=macOS'` 通过
- [x] [manual] 全新安装首次启动出现引导；点「打开系统设置」深链到屏幕录制面板
- [x] [manual] 拒绝后再次启动仍提示；在系统设置授权后「重新检测」变绿
- [x] [manual] 授权后点「重新启动 Cap」，重启后状态正确

## Scope

In:

- `Cap/Permissions/ScreenRecordingPermission.swift`（`CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess` / 深链 / 重新检测）
- `Cap/Permissions/OnboardingWindowController.swift`（SwiftUI 或 AppKit 均可）
- 重启当前 App 的按钮 / 动作
- 首次启动自动展示（`hasCompletedOnboarding` 先用 UserDefaults）

Out:

- 截图功能本身（#04）
- 权限状态的菜单栏常驻 UI（M3）

## Files

- `Cap/Permissions/ScreenRecordingPermission.swift`
- `Cap/Permissions/OnboardingWindowController.swift`
- `Cap/App/AppDelegate.swift`
- `CapTests/ScreenRecordingPermissionTests.swift`

## Notes

- 深链：`x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`
- App Sandbox 关闭，不需要 entitlements
- 已被拒绝的进程不会被再次询问，必须引导去系统设置

## Runs

### 2026-11-08 02:51 · run 1

- Auto: build ✅ / test 9 passed ✅（状态机 4 状态 + 重启委托）
- Manual live: 首次启动引导窗口 ✅（截图）；「打开系统设置」深链 ✅；TCC 授权 ✅（`Cap_Toggle value=1`；设置启动的新实例 preflight=true 跳过引导）
- Manual unit: 拒绝 / 需重启 / 重启委托由单测覆盖；「重新检测」按钮未逐像素点击（授权后窗口不再展示）
- Scope: 「运行中撤销权限的错误提示」移至 #04（截取失败路径）
