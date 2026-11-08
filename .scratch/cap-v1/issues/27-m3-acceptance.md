# 27 · M3 验收

Milestone: M3
Status: awaiting-manual
Blocked by: 23, 24, 25, 26
Type: feature

## Goal

按 DESIGN §7 M3 验收：装进 /Applications、登录自启、连续一周每天用；关键路径清单通过。

## Acceptance

- [x] [auto] build + 全部测试通过
- [x] [auto] popover/历史/设置的烟雾测试可脚本化部分（打开窗口、复制、删除）
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

## Runs

### 2026-11-08 10:24 · run 1

- Auto: build ✅ / test 129 passed ✅
- Auto: `/Applications/Cap.app` 已更新（含图标、popover、历史窗口、设置）
- Manual pending: 屏幕已锁，全部 GUI 项待解锁；登录自启需重启验证

### 2026-11-08 10:44 · run 2（代码评审修复）

独立评审 m3-reviewer 报告 PASS WITH ISSUES，已修复 9 条：
- 登录自启状态机（requiresApproval → 引导系统设置；错误不再被 refresh 清掉）
- 保存目录不存在时回退默认目录（+2 项测试）
- 剪枝/标注替换在索引写失败时不再留下不一致文件
- 保存成功对勾改为保存成功之后才显示
- popover 缩略图右键菜单（复制/Finder/删除）、设置区「清空历史…」
- 首次启动引导补充隐私文案
- DESIGN §6.2 默认登录自启首次启动自动注册一次
- `make-app-icon.py` 现在真的生成 `.icns`
- 测试 132 passed
