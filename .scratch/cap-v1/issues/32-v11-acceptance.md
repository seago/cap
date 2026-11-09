# 32 · v1.1 验收

Milestone: M4
Status: ready-for-agent
Blocked by: 28, 29, 30, 31
Type: feature

## Goal

v1.1 四项（滚动截图 / OCR / 贴图 / 上传）端到端验收，写清哪些进 v1.1、哪些退回 v1.2。

## Acceptance

- [ ] [auto] build + 全部测试通过
- [ ] [manual] 滚动截图在 Chrome/Safari 长页面可用或明确降级为「实验」
- [ ] [manual] OCR 中英混排可用
- [ ] [manual] 贴图可拖动/缩放/穿透/关闭
- [ ] [manual] 上传在本地 mock 端点跑通
- [ ] [manual] 既有 v1 路径无回归（⌘⇧2 → 标注 → Enter/⌘S/Esc、popover、历史）
