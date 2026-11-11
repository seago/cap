# App Store 上架材料草稿

> 账号下来后照着填 App Store Connect；`[]` 内为待确认项。

## 基本信息

- **App 名称**（≤30 字符）：`Cap`（需在 App Store Connect 检查是否被占用；备选 `Cap Screenshot`、`Cap: Screen Capture`）
- **副标题**（≤30 字符）：`快速截图 · 就地标注 · 长截图`
- **主分类**：Productivity；次分类：Graphics & Design
- **年龄分级**：4+
- **价格**：免费（无内购）
- **支持 URL / 营销 URL**：`[待定，建议 GitHub Pages 或个人站点]`
- **隐私政策 URL**（必须公网可访问）：`[待定；仓库私有，需单独托管，例如公开 Gist / GitHub Pages / 个人站点]`
- **版权**：`2026 [你的名字/公司]`

## 描述（中文草稿）

```
Cap 是一个轻快的 macOS 菜单栏截图工具：按 ⌘⇧2 框选或点窗口，就地标注，
Enter 复制、⌘S 保存；支持滚动长截图、OCR 取字、贴图钉屏和自定义全局快捷键。

- 区域 / 窗口 / 全屏截图，多显示器与跨屏选区
- 9 种标注工具：矩形、箭头、直线、文字、画笔、高亮、马赛克、序号、裁剪
- 滚动长截图：自动滚动拼接整页
- OCR：本地 Vision 识别中英文，结果直接复制
- 贴图钉屏：截图钉在屏幕上，可缩放/穿透
- 历史记录、自定义快捷键、上传到你自己配置的 HTTP 端点
- 界面支持简体中文 / English / 繁體中文
- 所有截图处理仅在本机完成；默认不联网
```

## Description (English draft)

```
Cap is a fast menu-bar screenshot tool for macOS: press ⌘⇧2 to select a region or
click a window, annotate in place, then press Enter to copy or ⌘S to save. It also
supports scrolling capture, on-device OCR, pinned screenshots, and custom hotkeys.

- Region / window / full-screen capture, multi-display and cross-display selection
- 9 annotation tools: rectangle, arrow, line, text, pen, highlight, mosaic, number, crop
- Scrolling capture: auto-scroll and stitch a full page
- OCR: on-device Vision recognition for Chinese and English
- Pinned screenshots: keep a capture floating on screen, zoom or click through
- History, custom global shortcuts, upload to your own HTTP endpoint
- UI in Simplified Chinese / English / Traditional Chinese
- All capture processing happens on-device; no network by default
```

## 关键词（≤100 字符，逗号分隔）

```
截图,截屏,标注,长截图,滚动截图,OCR,贴图,screenshot,capture,annotate,scroll capture,OCR
```

## App 隐私（App Privacy）

- **Data Not Collected**：Cap 不上传任何数据到开发者服务器；OCR/处理全在本机。
- 上传功能仅把图片 POST 到**用户自己配置的服务器**，由用户自行负责；App 不经过开发者中转。
- 无分析/广告 SDK、无跟踪（`NSPrivacyTracking = false`）。
- 需要在隐私政策里写清楚：屏幕录制/辅助功能权限用途、上传目的、数据保留由用户服务器决定。

## 隐私政策草稿（可托管到公开页面）

见仓库 `docs/privacy-policy.md`（含中英双语，公网地址待定）。

## 审核备注（App Review Notes 建议）

```
Cap is a menu-bar screenshot/annotation tool.

Screen Recording permission is required to capture the screen (ScreenCaptureKit).
Accessibility permission is optional and only used by the "Scrolling Capture"
feature to scroll the target window and stitch a long screenshot; all other
features work without it.

Cap works fully offline by default. The optional "Upload" feature POSTs a
screenshot only to an HTTP endpoint the user configures themselves; no data is
sent to the developer. No analytics, no tracking, no accounts.

The app is sandboxed; history is stored in the app container and screenshots are
saved to ~/Pictures/Screenshots (or a folder the user explicitly chooses).
```

## 截图清单（App Store 需要 1–5 张，建议 2560×1600 或 1440×900）

1. 全屏选择 + 窗口高亮
2. 编辑器工具条 + 标注效果
3. 滚动长截图结果（长图缩略示意）
4. OCR 识别结果 + 历史窗口
5. 贴图钉屏 + popover 设置/快捷键

## 上传前检查

- [ ] App 名称可用、BUNDLE ID 已注册
- [ ] 图标 1024×1024（`Cap/Resources/AppIcon-1024.png`）
- [ ] 隐私政策 URL 公网可访问
- [ ] 支持 URL 可访问
- [ ] App 隐私已填（Data Not Collected）
- [ ] 出口合规：`ITSAppUsesNonExemptEncryption = NO`（已加）
- [ ] 审核备注（上方）已粘贴
- [ ] TestFlight 内部测试通过
