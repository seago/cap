# ADR 0003 · 上传/分享采用用户自定义 HTTP 端点

- 状态：已采纳（2026-11-10）
- 相关：`.scratch/cap-v1/issues/31-upload.md`、`DESIGN.md` §10

## 背景

需要「上传截图并拿到分享链接」。候选：

1. 内置第三方图床（imgur 等）
2. 用户自建/自选 HTTP 端点
3. 只做剪贴板/本地共享

## 决策

采用 **用户自定义 HTTP 端点**，不内置任何第三方服务：

- `UploadService` 协议 + `HTTPUploadService` 默认实现（URLSession 可注入）；`UploadCoordinator` 串联「配置 → 编码 → 上传 → 复制链接 → 写回历史」。
- 配置项（UserDefaults）：`uploadEndpoint`、`uploadFieldName`（默认 `file`）、`uploadAuthorization`（可选 `Authorization` 头）、`uploadResponseURLKey`（可选响应字段）。
- 请求：`multipart/form-data` POST；响应自动识别 `url` / `link` / `imageUrl` / `data.url` / `data.link` 或纯文本 URL。
- 重试：超时/网络错误/5xx 重试 1 次；4xx 不重试。
- 未配置端点时隐藏上传入口（历史右键菜单项 + 编辑器按钮提示），避免用户点了才报错。
- 成功后 URL 写剪贴板并回写 `HistoryItem.uploadedURL`；失败仅提示、不动历史。

## 后果

- ✅ 不绑定任何图床账号/OAuth，用户可用任意兼容端点（自建、公司内部、支持 multipart 的图床）。
- ✅ 网络逻辑在 Upload 模块内，截图/编辑器主流程只消费结果（符合 DESIGN §10 架构接缝）。
- ⚠️ 鉴权值明文存 UserDefaults，只建议短期 token。
- ⚠️ 不内置服务意味着默认不可用：用户必须自己配置；文档提供本机 mock server 便于验收。
