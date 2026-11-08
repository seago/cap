# 25 · 设置：保存目录、格式、登录自启

Milestone: M3
Status: awaiting-manual
Blocked by: 22
Type: feature

## Goal

popover 内设置区：保存目录选择、PNG/JPEG 切换、登录自启开关；设置持久化到 UserDefaults。

## Acceptance

- [x] [auto] `SettingsStoreTests`：默认值、写读一致、保存目录不存在时回退默认
- [x] [auto] `FileExporter` 读取当前设置（格式/质量/目录）
- [x] [auto] build + 既有测试通过
- [ ] [manual] 改目录后 ⌘S 保存到新目录；切 JPEG 后保存为 .jpg
- [ ] [manual] 登录自启开关生效（`SMAppService.mainApp` 状态一致）

## Scope

In:

- `Cap/Settings/SettingsStore.swift`（UserDefaults 封装）
- `Cap/Settings/LaunchAtLogin.swift`（SMAppService）
- popover 设置区 UI

Out:

- 快捷键录制（v1 固定 ⌘⇧2，见 DESIGN §11 已确认范围）

## Files

- `Cap/Settings/SettingsStore.swift`
- `Cap/Settings/LaunchAtLogin.swift`
- `Cap/MenuBar/MenuBarPopoverView.swift`
- `CapTests/SettingsStoreTests.swift`
- `Cap.xcodeproj/project.pbxproj`

## Runs

### 2026-11-08 10:24 · run 1

- Auto: build ✅ / test 129 passed ✅（SettingsStore 5 项：默认值/读写/空目录回退/非法格式回退/格式扩展名）
- 实现: `SettingsStore`（UserDefaults 注入）、`LaunchAtLoginController`（SMAppService.mainApp）、popover 设置区（保存目录选择、PNG/JPEG 切换、登录自启开关）；⌘S 保存按设置生效
- Manual pending: 屏幕已锁，需解锁后验证改目录/切 JPEG/自启开关
