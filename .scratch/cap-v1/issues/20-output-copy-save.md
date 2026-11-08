# 20 · 输出：复制 / 保存 / 取消

Milestone: M2
Status: ready-for-agent
Blocked by: 16
Type: feature

## Goal

Enter 或 ⌘C 复制标注版并关闭；⌘S 保存标注版到默认目录并同步复制；Esc 关闭并保留原图。

## Acceptance

- [ ] [auto] `FileNamingTests`：`Cap 2026-11-08 at 01.30.00.png` 格式；重名追加 ` 2`、` 3`；非法字符替换
- [ ] [auto] `FileExporterTests`（临时目录）：PNG 写出尺寸正确；JPEG 质量参数生效
- [ ] [auto] 历史替换：标注版替换原图条目并置 `isAnnotated = true`（store 层单测）
- [ ] [auto] `xcodebuild test` 通过
- [ ] [manual] Enter 复制标注版到剪贴板并关闭编辑器
- [ ] [manual] ⌘S 保存到 `~/Pictures/Screenshots/` 且剪贴板同步更新
- [ ] [manual] Esc 关闭编辑器，剪贴板与历史保留原图

## Scope

In:

- `Cap/Support/FileNaming.swift`
- `Cap/Output/FileExporter.swift`（PNG/JPEG、目录自动创建、重名递增）
- `Cap/History/HistoryStore.swift`：`replaceWithAnnotated(id:image:)`
- 编辑器调用连线

Out:

- 保存目录选择 UI、格式切换 UI（M3）

## Files

- `Cap/Support/FileNaming.swift`
- `Cap/Output/FileExporter.swift`
- `Cap/History/HistoryStore.swift`
- `Cap/Editor/EditorController.swift`
- `CapTests/FileNamingTests.swift`
- `CapTests/FileExporterTests.swift`
- `CapTests/HistoryStoreTests.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- 保存失败保留编辑器并提示
- 时间格式与命名规则见 DESIGN §3.5
