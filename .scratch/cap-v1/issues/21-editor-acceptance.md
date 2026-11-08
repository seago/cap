# 21 · 编辑器验收与稳健性

Milestone: M2
Status: awaiting-manual
Blocked by: 18, 19, 20
Type: feature

## Goal

按 DESIGN §7 M2 验收清单跑通编辑器，处理边界与失败情况。

## Acceptance

- [x] [auto] build + 全部测试通过
- [x] [auto] 大图（Retina 3840×2400）渲染耗时记录 < 500ms
- [ ] [manual] 标准组每个工具各画一次并分别 Enter 输出，图正确
- [ ] [manual] 撤销 10 步回到原图；重做 10 步恢复
- [ ] [manual] 中文输入正常；Retina 导出像素与原图一致
- [ ] [manual] 重名保存不覆盖
- [ ] [manual] 编辑器打开时再按 ⌘⇧2 不出现重入/崩溃（忽略或先关闭当前编辑器）
- [ ] [manual] 保存失败（目录只读）保留编辑器并提示

## Scope

In:

- 边界与重入保护
- 性能检查与必要优化
- 失败提示文案

Out:

- 历史窗口、菜单栏 popover（M3）

## Files

- `Cap/Editor/EditorController.swift`
- `Cap/Editor/EditorCanvasView.swift`
- `Cap/App/AppDelegate.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- DESIGN §9 风险 #4（非激活面板输入）在此收口

## Runs

### 2026-11-08 09:14 · run 1

- Auto: build ✅ / test 104 passed ✅
- Auto: 3840x2400 + 20 条标注渲染 3.7ms（阈值 500ms，独立 CLI 与单测双重测量）
- Auto: 编辑器重入保护（`editorController != nil` 时忽略 ⌘⇧2）、重复 close 幂等
- Manual pending: 屏幕锁定，全部人工项（逐工具输出、10 步撤销、中文输入、重名保存、只读目录）待解锁
