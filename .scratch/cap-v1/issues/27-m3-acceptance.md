# 27 · M3 验收

Milestone: M3
Status: ready-for-agent
Blocked by: 23, 24, 25, 26
Type: feature

## Goal

按 DESIGN §7 M3 验收：装进 /Applications、登录自启、连续一周每天用；关键路径清单通过。

## Acceptance

- [ ] [auto] build + 全部测试通过
- [ ] [auto] popover/历史/设置的烟雾测试可脚本化部分（打开窗口、复制、删除）
- [ ] [manual] /Applications/Cap.app 登录自启生效，重启后仍在
- [ ] [manual] 关键路径：⌘⇧2 → 区域/窗口/全屏 → 标注 → Enter/⌘S → 历史找回
- [ ] [manual] 连续使用无崩溃、无内存增长异常

## Scope

In:

- 集成缺陷修复、提示文案、日志补齐

Out:

- v1.1 功能

## Files

- `Cap/App/AppDelegate.swift`
- `Cap/MenuBar/MenuBarController.swift`
- `Cap.xcodeproj/project.pbxproj`
