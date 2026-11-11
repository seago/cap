# App Store Sandbox 兼容 Spike

- 日期：2026-11-12
- 分支：`appstore-sandbox`
- 目标：验证 Cap 在 **App Sandbox** 下核心功能是否可用，作为能否上架 Mac App Store 的可行性依据
- 方法：Release 构建 + `Cap/Resources/Cap.entitlements`（ad-hoc/本机自签 `Cap Local Signing` 签名，bundle id 仍为 `dev.bruce.cap`，复用已有 TCC 授权），安装到 `/Applications/Cap.app` 实机验证

## 1. 结论

**可行。** 沙盒下 v1.1 全部核心能力实测正常；需要为上架做 4 处代码/工程调整 + 1 套 Apple 账号与元数据流程。无阻塞性技术问题。

## 2. Entitlements（spike 已验证）

```xml
com.apple.security.app-sandbox            = true
com.apple.security.network.client         = true   // 上传
com.apple.security.files.user-selected.read-write = true // 用户选择保存目录
com.apple.security.assets.pictures.read-write     = true // 默认 ~/Pictures/Screenshots
```

## 3. 实测结果

| 能力 | 沙盒下结果 | 证据 |
|---|---|---|
| 启动 / 菜单栏 popover | ✅ | 正常显示；容器 `~/Library/Containers/dev.bruce.cap` 自动创建 |
| 屏幕录制权限 | ✅ | 同一签名身份复用授权，日志 `Screen recording permission: true` |
| 全局热键（⌘⇧2 / ⌘⇧7 / ⌥⌘P） | ✅ | 日志 `Registered global hotkey` ×3；热键触发选区 |
| 区域截图 → 编辑器 → Enter 复制 | ✅ | 剪贴板 PNG 正常；`CaptureResult` 无沙盒错误 |
| 滚动长截图（AXRaise + HID 滚动） | ✅ | Chrome 长页 9 帧 → 940×1092 拼接成功（说明 AX 权限 + 合成滚动事件在沙盒下可用） |
| OCR | ✅ | Vision 识别成功，`ocrText` 写回容器索引 |
| 贴图钉屏 | ✅ | 浮窗创建；拖动/缩放/关闭路径可用 |
| 历史 | ✅ | 写入容器 `Data/Library/Application Support/Cap/History/`，真实 home 不受影响 |
| 默认保存到 `~/Pictures/Screenshots` | ⚠️ 需修 → 已修 | 沙盒下 `homeDirectoryForCurrentUser` 指向容器；用 `getpwuid` 取真实 home 后写真实 Pictures 成功（已有 `assets.pictures.read-write`） |
| 用户自选保存目录 | ⚠️ 未修 | 现在只存路径字符串；沙盒下重启后需 **security-scoped bookmark** 才能继续访问 |
| 登录自启（SMAppService.mainApp） | ✅ | `sfltool dumpbtm`：`2.dev.bruce.cap` / `/Applications/Cap.app`，状态 `enabled, allowed` |
| 上传（network.client） | ✅ | 本机 mock：`127.0.0.1:8766`、局域网 IP `192.168.1.157:8767` 的 HTTP 直连均成功 |
| 上传域名 HTTP | ⚠️ 待定 | ATS 对域名 HTTP 会拦截；App Store 版建议要求 HTTPS（或加 ATS 例外并说明理由） |

## 4. 上架前必须的改动

1. **真实 home 目录**（本 spike 已实现 `Cap/Support/UserHome.swift`）：默认保存目录用 `getpwuid` 的真实 home，避免静默落到容器。
2. **用户选择目录**：设置里保存 `security-scoped bookmark`（Data），读取时 `startAccessingSecurityScopedResource()`；否则 App 重启后无法写入用户选的任意目录。
3. **ATS 策略**：上传端点默认要求 `https://`；仅对 `localhost/LAN IP` 放行 HTTP（或提供显式警告）。App Review 会看网络行为说明。
4. **测试钩子**：`CAP_EDITOR_CAPTURABLE` 用 `#if DEBUG` 包起来，Release 不保留。
5. **签名 / 分发**：Apple Developer Program（$99/年）→ App Store Connect 建 App（bundle id 可继续 `dev.bruce.cap`）→ Distribution 证书 + provisioning（Xcode 自动管理）→ Upload to App Store Connect / TestFlight；`get-task-allow` 由 distribution profile 自动去掉。

## 5. 上架流程清单

- [ ] 注册 Apple Developer Program（个人/公司），拿到 Team ID
- [ ] App Store Connect：新建 macOS App（名称需唯一，`Cap` 可能被占/近似，预留 `Cap Screenshot` 备选）
- [ ] App 图标 1024×1024、截图（6.9"/13" Mac 尺寸）、描述、关键词、支持 URL、隐私政策 URL
- [ ] App 隐私：图片经用户配置的服务器上传 → 声明「用户内容」处理方式；无分析 SDK
- [ ] 出口合规：仅 HTTPS → `ITSAppUsesNonExemptEncryption = NO`
- [ ] 权限文案：屏幕录制 + 辅助功能（滚动截图）需在描述/审核备注中说明用途
- [ ] TestFlight 内部测试 → 提交审核（通常 1–3 天，可能多轮）
- [ ] 审核关注点：屏幕录制用途、辅助功能必要性（Xnip/iShot/Snap 等同类 App 已在 MAS 上架，先例充分）、用户自定义上传端点

## 6. 工作量估算

| 项 | 估算 |
|---|---|
| 代码/工程改造（bookmark、ATS、#if DEBUG、entitlements 收尾） | 1–2 天 |
| App Store Connect 元数据 + TestFlight | 0.5–1 天 |
| 审核与整改 | 1–3 天（含等待） |
| 合计（不含 $99 账号申请等待） | **约 1 周内**可上架 |

## 7. 与 GitHub 分发的关系

- App Store 版与 GitHub Releases 版可并存：MAS 版必须沙盒、由 App Store 签名分发；GitHub 版保持自签 + 公证路线。
- 两个渠道的历史/设置目录不同（容器 vs 真实 home），互不迁移；MAS 版首次启动是干净状态。
