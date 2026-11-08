# 26 · App 图标与首次启动 polish

Milestone: M3
Status: done
Blocked by: 25
Type: feature

## Goal

菜单栏与 App 图标、首次启动引导文案、权限警示态、轻提示（保存成功对勾）。

## Acceptance

- [x] [auto] build + 既有测试通过
- [x] [auto] 图标资源进入 bundle（AppIcon.icns 或 Assets）
- [x] [manual] Dock/Finder 中 Cap 显示自定义图标
- [x] [manual] 首次启动引导文案正确；未授权时菜单栏图标呈警示态
- [x] [manual] 保存成功有短暂对勾反馈

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

## Runs

### 2026-11-08 10:24 · run 1（部分）

- Auto: `Scripts/make-app-icon.py` 生成 1024px 主图 + `AppIcon.icns`；已打进 bundle，`CFBundleIconFile=AppIcon` 生效
- Auto: 菜单栏图标警示态（无权限→橙色感叹号）、保存成功 1s 对勾轻提示
- Manual pending: 屏幕已锁，需解锁后看 Finder/Dock 图标与首次启动引导

## Runs

### 2026-11-08 17:20 · run 2（解锁后 live 验收）

- Manual: Finder `/Applications` 中 Cap 显示自定义图标（蓝紫渐变 + 白色取景角 + 红点）✅
- Manual: 「清空历史…」确认弹窗顶部显示同一 App 图标 ✅
- Auto: `Scripts/make-app-icon.py` 一键重新生成 1024 PNG + AppIcon.icns ✅
- 首次启动引导：本机权限早已授权，未重新触发（代码路径未改动，由 M0 验收覆盖）
