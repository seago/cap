# 14 · 自身窗口排除与错误路径

Milestone: M1
Status: ready-for-agent
Blocked by: 11, 13
Type: feature

## Goal

保证截图里永远不出现 Cap 自己的 UI；权限被撤销或截取失败时有明确提示。

## Acceptance

- [ ] [auto] build + 全部测试通过
- [ ] [auto] 失败错误映射单测：权限撤销 → `.permissionDenied`；无显示器 → `.displayNotFound`
- [ ] [manual] 分别对全屏 App、普通窗口、跨 Space 窗口截图，图片中无覆盖层/灰罩/菜单栏图标
- [ ] [manual] 系统设置里撤销屏幕录制权限后按 ⌘⇧2，出现明确错误提示，不崩溃
- [ ] [manual] 恢复权限后无需重启即可继续截图（若不行则提示重启，并记录）

## Scope

In:

- 截取前关闭/隐藏覆盖层并等待一帧
- `sharingType = .none` 验证；不生效时的隐藏回退路径
- 错误 alert 文案与权限引导入口

Out:

- 其他 M2 功能

## Files

- `Cap/Selection/SelectionOverlayController.swift`
- `Cap/Capture/ScreenCaptureService.swift`
- `Cap/App/AppDelegate.swift`
- `CapTests/CaptureErrorMappingTests.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- DESIGN §9 风险 #2 的验证点
