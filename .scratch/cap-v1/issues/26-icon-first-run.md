# 26 · App 图标与首次启动 polish

Milestone: M3
Status: ready-for-agent
Blocked by: 25
Type: feature

## Goal

菜单栏与 App 图标、首次启动引导文案、权限警示态、轻提示（保存成功对勾）。

## Acceptance

- [ ] [auto] build + 既有测试通过
- [ ] [auto] 图标资源进入 bundle（AppIcon.icns 或 Assets）
- [ ] [manual] Dock/Finder 中 Cap 显示自定义图标
- [ ] [manual] 首次启动引导文案正确；未授权时菜单栏图标呈警示态
- [ ] [manual] 保存成功有短暂对勾反馈

## Scope

In:

- `Cap/Resources/Assets.xcassets`（AppIcon）、Info.plist icon 配置
- `MenuBarController` 警示态 / 成功轻提示
- 首次启动引导文案微调

Out:

- 应用商店图标规范、公证

## Files

- `Cap/Resources/Assets.xcassets`
- `Cap/Resources/Info.plist`
- `Cap/MenuBar/MenuBarController.swift`
- `Cap/Permissions/OnboardingWindowController.swift`
- `Cap.xcodeproj/project.pbxproj`
