# 32 · v1.1 验收

Milestone: M4
Status: done
Blocked by: 28, 29, 30, 31
Type: feature

## Goal

v1.1 四项（滚动截图 / OCR / 贴图 / 上传）端到端验收，写清哪些进 v1.1、哪些退回 v1.2。

## Acceptance

- [x] [auto] build + 全部测试通过
- [x] [manual] 滚动截图在 Chrome/Safari 长页面可用或明确降级为「实验」
- [x] [manual] OCR 中英混排可用
- [x] [manual] 贴图可拖动/缩放/穿透/关闭
- [x] [manual] 上传在本地 mock 端点跑通
- [x] [manual] 既有 v1 路径无回归（⌘⇧2 → 标注 → Enter/⌘S/Esc、popover、历史）

## Runs

### 2026-11-10 00:40 · run 1（整体验收通过）

完整报告：`.scratch/cap-v1/acceptance-v1.1.md`

- Auto: 全量 **191 项测试通过**；Release Universal 安装包校验（x86_64+arm64、bundle/版本/最低系统/三语资源/签名）
- Manual: v1 路径回归（⌘⇧2 → 箭头标注 → Enter 复制 600×450 PNG → 历史标注版；⌘S 落盘；Esc 保留原图；历史删除 11→10）
- Manual: 滚动截图 Chrome 长页 10 帧 → 940×2454 无缝；OCR 中英混排复制 + `ocrText` 入库；贴图拖动/缩放/穿透/关闭；上传 mock 端点成功
- Manual: 三语界面（zh-Hans / en / zh-Hant）全部通过；此前锁屏 Deferred 的 zh-Hant 已补测
- Deferred（无阻塞，6 项）：重启登录项、onboarding 重触发、破坏性清空历史、真实中文 IME、只读目录保存失败弹窗、Safari 滚动截图
