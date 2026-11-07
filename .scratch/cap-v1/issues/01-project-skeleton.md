# 01 · 工程骨架与菜单栏 App

Milestone: M0
Status: ready-for-agent
Blocked by:
Type: feature

## Goal

建立一个可 `xcodebuild` 构建的 macOS App 工程：Cap 以菜单栏 App 启动，Dock 不显示图标，能退出。

## Acceptance

- [ ] [auto] `xcodebuild -project Cap.xcodeproj -scheme Cap -configuration Debug build` 退出码 0
- [ ] [auto] 构建产物 Info.plist 中 `LSUIElement = YES`、`CFBundleIdentifier = dev.bruce.cap`、`CFBundleShortVersionString = 0.1.0`、`LSMinimumSystemVersion = 15.2`
- [ ] [auto] `xcodebuild test -project Cap.xcodeproj -scheme Cap -destination 'platform=macOS'` 通过，至少 1 个 Swift Testing 用例
- [ ] [manual] 启动 `.app` 后菜单栏出现 Cap 图标；Dock 无图标；菜单里的「退出 Cap」可退出

## Scope

In:

- `Cap.xcodeproj`（手写 pbxproj，本机无 xcodegen / tuist）
- `Cap/App/CapApp.swift`、`Cap/App/AppDelegate.swift`、`Cap/MenuBar/MenuBarController.swift`
- `Cap/Support/Logging.swift`（OSLog，subsystem `dev.bruce.cap`，分类 capture / selection / editor / history）
- `Cap/Resources/Info.plist`
- `CapTests/AppInfoTests.swift`
- shared scheme `Cap`

Out:

- 快捷键、截图、权限、历史、设置、图标设计
- 自签证书与 Release 打包（#06）

## Files

- `Cap.xcodeproj/project.pbxproj`
- `Cap.xcodeproj/xcshareddata/xcschemes/Cap.xcscheme`
- `Cap/App/CapApp.swift`
- `Cap/App/AppDelegate.swift`
- `Cap/MenuBar/MenuBarController.swift`
- `Cap/Support/Logging.swift`
- `Cap/Resources/Info.plist`
- `CapTests/AppInfoTests.swift`

## Notes

- Swift 6 language mode；`MACOSX_DEPLOYMENT_TARGET = 15.2`
- App Sandbox 关闭；`LSUIElement = YES`
- Debug 用 ad-hoc 签名即可；稳定签名在 #06
- 菜单栏图标先用 SF Symbol（如 `camera.viewfinder`），图标设计不在本 ticket
