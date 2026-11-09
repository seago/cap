# 29 · OCR 文字识别

Milestone: M4
Status: awaiting-manual
Blocked by: 28
Type: feature

## Goal

对截图（或历史图片）做本地 OCR：Vision `VNRecognizeTextRequest`，中英混排，结果可复制或存文本；`HistoryItem` 预留 `ocrText` 字段。

## Acceptance

- [x] [auto] `OCRTests`：合成中英文字位图 → 识别文本包含预期词；空图返回空
- [x] [auto] `HistoryItem` 向后兼容解码（旧 index.json 无 ocrText）
- [x] [auto] 识别在后台队列执行，不阻塞主线程（接口 async）
- [x] [auto] build + 既有测试通过
- [ ] [manual] 对真实截图识别中英文，复制文本正确；历史窗口可对单条识别
- [ ] [manual] 识别失败/无文字时提示清楚

## Scope

In:

- `Cap/OCR/TextRecognizer.swift`（Vision 封装，async）
- `Cap/OCR/OCRResult.swift`（行 + 置信度 + 整段文本）
- `HistoryItem.ocrText`、`HistoryStore` 更新 ocrText
- 历史窗口右键「识别文字」→ 复制文本 sheet；编辑器/截图后可选识别
- 可注入假 recognizer 便于测试

Out:

- 文本区域选择（框选部分文字）、实时识别、翻译

## Runs

### 2026-11-09 17:40 · run 1（代码完成）

- Auto: `VisionTextRecognizer`（中文/英文、accurate、离线）+ `OCRTests` 7 项全绿（合成中英文图识别出 Cap/OCR/测试文字、空白图返回空、阅读顺序、旧索引兼容、`setOCRText` 落盘与重载、未知 id 抛错、可注入假识别器）
- 实现: `HistoryItem.ocrText`（向后兼容）、`HistoryStore.setOCRText`、历史窗口右键「识别文字」→ 复制文本并写回索引
- Manual pending: 屏幕锁定，待解锁后在真实截图上验中英文识别与右键菜单
