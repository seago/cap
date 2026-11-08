# 16 · 标注渲染器

Milestone: M2
Status: ready-for-agent
Blocked by: 15
Type: feature

## Goal

把 `EditorSession` 的标注渲染到原图像素尺寸的位图上，Retina 下清晰；支持全部 9 种工具与裁剪。

## Acceptance

- [ ] [auto] `AnnotationRendererTests`：单选工具渲染后目标像素颜色/覆盖范围符合预期（矩形描边、箭头实心、高亮半透明、序号圆形底）
- [ ] [auto] 裁剪后渲染尺寸正确；空 session 返回原图尺寸
- [ ] [auto] 导出图片像素尺寸 = 原图尺寸（不受显示缩放影响）
- [ ] [auto] `xcodebuild test` 通过
- [ ] [manual] 逐工具肉眼检查：矩形/箭头/直线/文字/画笔/高亮/马赛克/序号/裁剪

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
