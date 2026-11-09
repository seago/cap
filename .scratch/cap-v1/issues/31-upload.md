# 31 · 上传 / 分享

Milestone: M4
Status: done
Blocked by: 30
Type: feature

## Goal

按 DESIGN §10：先定上传目标。默认实现「自定义 HTTP 端点」（可配置 URL/字段/鉴权），架构上 `UploadService` 协议，不把网络塞进截图流程。

## Acceptance

- [x] [auto] `UploadServiceTests`：multipart 构造正确、失败重试 1 次、超时取消、错误类型可区分
- [x] [auto] 成功返回 URL 后可写剪贴板
- [x] [auto] build + 既有测试通过
- [x] [manual] 配置一个本地测试端点后上传成功，剪贴板得到 URL
- [x] [manual] 未配置时按钮隐藏/提示；网络失败提示清楚且不丢历史

## Scope

In:

- `Cap/Upload/UploadService.swift`（protocol + 默认 HTTP 实现，URLSession 注入）
- `Cap/Upload/UploadSettings.swift`（UserDefaults：endpoint、字段名、鉴权 header、上传后动作）
- 编辑器/历史窗口「上传」入口与进度提示
- 本地测试端点脚本（`Scripts/mock-upload-server.py`）

Out:

- 内置图床（imgur 等）、分享菜单、OAuth

## Notes

- 默认不配置任何第三方服务；用户填自己的端点

## Runs

### 2026-11-10 00:25 · run 1

- Auto: `UploadServiceTests` 12 项（multipart 构造、JSON/嵌套/纯文本解析、成功返回 URL、5xx 重试 1 次、4xx 不重试、超时分类、无效响应、空数据、设置持久化/校验/reset）；全量 191 项测试绿
- Auto: 成功返回 URL 后写剪贴板（`UploadCoordinator.uploadPNG` + 实机验证）
- Manual: 本地 mock 端点（`Scripts/mock-upload-server.py`）配置后，历史右键上传成功 → 剪贴板得到 `http://127.0.0.1:8765/uploads/….png`、索引写回 `uploadedURL`、卡片显示「380×235 · 已上传」✅
- Manual: 端点服务停止后上传 → 状态栏「上传失败：网络错误：无法连接服务器。」，历史条数与内容不变 ✅
- Manual: 清空端点配置 → 历史右键菜单不再出现「上传并复制链接」（隐藏）✅
