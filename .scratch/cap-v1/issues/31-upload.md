# 31 · 上传 / 分享

Milestone: M4
Status: ready-for-agent
Blocked by: 30
Type: feature

## Goal

按 DESIGN §10：先定上传目标。默认实现「自定义 HTTP 端点」（可配置 URL/字段/鉴权），架构上 `UploadService` 协议，不把网络塞进截图流程。

## Acceptance

- [ ] [auto] `UploadServiceTests`：multipart 构造正确、失败重试 1 次、超时取消、错误类型可区分
- [ ] [auto] 成功返回 URL 后可写剪贴板
- [ ] [auto] build + 既有测试通过
- [ ] [manual] 配置一个本地测试端点后上传成功，剪贴板得到 URL
- [ ] [manual] 未配置时按钮隐藏/提示；网络失败提示清楚且不丢历史

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
