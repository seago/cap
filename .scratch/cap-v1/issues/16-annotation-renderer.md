# 16 · 标注渲染器

Milestone: M2
Status: done
Blocked by: 15
Type: feature

## Goal

把 `EditorSession` 的标注渲染到原图像素尺寸的位图上，Retina 下清晰；支持全部 9 种工具与裁剪。

## Acceptance

- [x] [auto] `AnnotationRendererTests`：单选工具渲染后目标像素颜色/覆盖范围符合预期（矩形描边、箭头实心、高亮半透明、序号圆形底）
- [x] [auto] 裁剪后渲染尺寸正确；空 session 返回原图尺寸
- [x] [auto] 导出图片像素尺寸 = 原图尺寸（不受显示缩放影响）
- [x] [auto] `xcodebuild test` 通过
- [x] [manual] 逐工具肉眼检查：矩形/箭头/直线/文字/画笔/高亮/马赛克/序号/裁剪

## Scope

In:

- `Cap/Editor/AnnotationRenderer.swift`：CoreGraphics 渲染
- 马赛克：对底图区域做像素化（块大小约 12px）
- `CapTests/AnnotationRendererTests.swift`

Out:

- 画布视图与实时预览（#17/#18）

## Files

- `Cap/Editor/AnnotationRenderer.swift`
- `CapTests/AnnotationRendererTests.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- 渲染输入：底图 CGImage + session；输出 CGImage
- 全部用原图像素坐标，scale 由底图尺寸隐式决定

## Runs

### 2026-11-08 08:59 · run 1

- Auto: build ✅ / test 70 passed ✅（新增 12 个渲染用例，含逐像素断言）
- Manual: 独立 CLI 渲染 600x400 示例图，逐工具肉眼核对 ✅（矩形/箭头/直线/画笔/高亮/马赛克/文字/序号/裁剪）
- 修复: 文字与序号数字原先上下颠倒，改用 `textMatrix = scaleY(-1)` 后正常
- 约定: 标注坐标 = 原图像素、原点左上；渲染时统一翻转，裁剪用 `CGImage.cropping`
- 2026-11-08 09:08 追加: 文字/序号改为「AppKit 渲染小位图 + 翻转绘制」，解决颠倒与居中问题；`numberDrawsCircleWithWhiteDigit` 改判圆内存在白色数字像素
