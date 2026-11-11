# Cap

macOS 菜单栏常驻的截图工具。[English](README.en.md) · 设计稿见 `DESIGN.md`（[English](DESIGN.en.md)），实施记录见 `.scratch/cap-v1/`。

**下载**：[最新 Release](https://github.com/seago/cap/releases)（dmg 拖拽安装 / zip 解压安装；私有仓库需登录 GitHub）。

## 构建与测试

```bash
xcodebuild -project Cap.xcodeproj -scheme Cap -configuration Debug build
xcodebuild test -project Cap.xcodeproj -scheme Cap -destination 'platform=macOS'
```

## 签名与安装

本机使用自签 codesigning 身份，保证重建后 TCC 不失效：

```bash
Scripts/make-signing-identity.sh
Scripts/install.sh
```

首次运行后，在「系统设置 → 隐私与安全性 → 录屏与系统录音」中勾选 Cap。

## 功能

- **⌘⇧2 截图**：拖拽选区 / 单击窗口 / Enter 截全屏；多显示器按屏幕分别选区
- **编辑器**：冻结面板 + 就地工具条，9 种工具（矩形、箭头、直线、文字、画笔、高亮、马赛克、序号、裁剪），撤销/重做，中文输入法
- **输出**：Enter 复制标注版、⌘S 保存到 `~/Pictures/Screenshots/`、Esc 保留原图
- **菜单栏 popover**：权限状态、最近 8 张截图（点击复制）、打开历史窗口、设置
- **历史窗口**：全部截图网格、双击预览、复制、Finder 显示、删除、清空
- **设置**：保存目录、PNG/JPEG 格式、登录自启、**自定义全局快捷键**（截图/滚动截图/贴图穿透切换，点击录制，⌫ 恢复默认，Esc 取消）；历史最多保留 100 张（自动删最旧）
- **滚动长截图（v1.1）**：⌘⇧7 框选可滚动区域，自动滚动并拼接成长图；Esc 中止
- **OCR（v1.1）**：历史窗口右键「识别文字」，本地 Vision 识别中英文并复制文本
- **贴图钉屏（v1.1）**：编辑器 ⌘T 或历史右键「贴到屏幕」把截图钉成浮窗；拖动移动、滚轮缩放、双击复位、Esc 关闭、右键复制/点击穿透；⌥⌘P 全局切换穿透
- **多语言（v1.1）**：简体中文 / English / 繁體中文，跟随系统语言切换（String Catalog，无需手动设置）
- **上传/分享（v1.1）**：设置区填自己的 HTTP 端点（可选鉴权头/字段名），历史右键「上传并复制链接」或编辑器上传按钮，成功后链接自动进剪贴板；不内置图床

## 常用快捷键

| 动作 | 默认 | 说明 |
|---|---|---|
| 截图 | ⌘⇧2 | 拖拽选区 / 单击窗口 / Enter 全屏 |
| 滚动长截图 | ⌘⇧7 | 框选可滚动区域后自动滚动拼接；Esc 中止 |
| 贴图穿透切换 | ⌥⌘P | 所有贴图窗口在「可点击 / 点击穿透」之间切换 |

三个快捷键都可以在菜单栏 popover → 设置 → 快捷键 里点击录制修改（⌫ 恢复默认、Esc 取消）。

## 权限

- 屏幕录制：截图必需
- 辅助功能：滚动长截图自动滚动目标 App 时必需（系统设置 → 隐私与安全性 → 辅助功能）

## 数据位置

- 历史：`~/Library/Application Support/Cap/History/`（`index.json` + `images/` + `thumbs/`）
- 保存：默认 `~/Pictures/Screenshots/`，可在菜单栏 popover 中修改

## 支持的 Mac

- 安装产物是 **Universal binary**：Apple Silicon（arm64）与 Intel（x86_64）都能运行。
  ```bash
  lipo -info /Applications/Cap.app/Contents/MacOS/Cap
  # x86_64 arm64
  ```
- 最低系统 **macOS 15.2**（见 `DESIGN.md` §11）。Intel 机型需支持升级到 macOS Sequoia 15.2：
  - MacBook Pro 2018 及之后（含 16 英寸 2019）、MacBook Air（2020 Intel）
  - iMac 2019 及之后、iMac Pro 2017、Mac mini 2018、Mac Pro 2019
  - 更老的 Intel Mac（Ventura/Sonoma 及以下）不在 v1 支持范围内
- Debug 构建只编译当前机器架构（`ONLY_ACTIVE_ARCH=YES`）；**Release / `Scripts/install.sh` 产物才是 Universal**。
- `Cap Local Signing` 自签身份只在本机受信。拷到另一台 Mac（含 Intel）需要重新签名并重新授予屏幕录制权限；分发给他人需要正式签名 + 公证。

## 发布版本（GitHub Releases）

仓库是 **private**，Release 仅自己和 collaborator 可见。发布流程已自动化：

```bash
# 1. 确认版本号（Cap.xcodeproj 的 MARKETING_VERSION）
# 2. 打 tag 并推送 → GitHub Actions 自动测试 + 构建 Universal zip + 创建 Release
git tag -a v0.1.0 -m "Cap v0.1.0"
git push origin v0.1.0
```

- 工作流：`.github/workflows/release.yml`（test → build & package → `gh release create`）
- 产物：`Cap-<版本>-macos-universal.dmg`（拖进 Applications 安装）+ `Cap-<版本>-macos-universal.zip`（解压安装）+ SHA256（x86_64 + arm64），说明文件由 `Scripts/make-release.sh` 生成
- 也可在 GitHub Actions 页面手动 `Run workflow` 填版本号，或本地 `Scripts/make-release.sh` 打包后网页上传
- **CI 产物是 ad-hoc 签名（未公证）**：首次打开需右键 → 打开；若提示「已损坏」执行
  `xattr -dr com.apple.quarantine /Applications/Cap.app`。
  想要双击直接打开 / 分发给别人，需要 Apple Developer Program（Developer ID + 公证）。
- CI 使用 `macos-26` runner（与本地 Xcode 版本接近）；私有仓库的 Actions 消耗每月免费额度（macOS runner 按 10 倍计费）；Actions 被关掉时工作流不会跑，可在
  仓库 Settings → Actions → General 启用后重新运行。

## 项目结构

```text
Cap/
  App/            AppDelegate、入口
  MenuBar/        NSStatusItem、popover、历史窗口
  Capture/        ScreenCaptureKit 采集、窗口索引
  Selection/      多屏选区覆盖层
  Editor/         冻结面板、标注模型与渲染、工具条、画布交互、文字输入
  Scroll/         滚动长截图（帧采集、自动滚动、拼接）
  Pin/            贴图钉屏浮窗
  OCR/            Vision 文字识别
  Output/         剪贴板、PNG/JPEG 编码与保存
  History/        历史索引、缩略图、剪枝
  Settings/       UserDefaults 设置、登录自启、快捷键录制控件
  Resources/      Info.plist、AppIcon
Scripts/          签名身份、安装、图标生成
CapTests/         Swift Testing 单测（模型/算法/渲染/设置）
```

## 上传（可选）

默认不配置任何上传服务。在菜单栏 popover → 设置 → 上传 里填写自己的 HTTP 端点（需接受 `multipart/form-data` 的 `file` 字段，返回 JSON `{"url": "..."}` 或纯文本 URL）。本地验收可用自带脚本：

```bash
python3 Scripts/mock-upload-server.py --port 8765 --dir /tmp/cap-uploads
# 再在设置里填 http://127.0.0.1:8765/upload
```

响应会依次尝试 `url` / `link` / `data.url` 等字段，也接受纯文本 URL；鉴权头以 `Authorization` 发送。鉴权值以明文存在 UserDefaults，只建议填短期 token。

## 故障排查

- **⌘⇧2 没反应**：确认 `/Applications/Cap.app` 在运行；权限被撤销时菜单栏图标会变成橙色感叹号，点开 popover 按提示重新授权。
- **滚动截图提示需要辅助功能**：系统设置 → 隐私与安全性 → 辅助功能 勾选 Cap（macOS 27 上首次授权需要输入管理员密码）。
- **改了代码后权限失效**：确认用 `Scripts/install.sh` 安装（稳定自签身份 `Cap Local Signing`），不要用 ad-hoc 签名重建。
- **构建报 `unable to find xcodebuild` 或 SDK 错误**：本机 `DEVELOPER_DIR` 可能过期，构建时加前缀：
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ...`
- **上传失败**：确认端点 URL 可访问、返回 2xx 且响应含合法 URL；HTTP 4xx 不重试（多为鉴权/配置问题），5xx 与网络错误会自动重试 1 次。
- **历史/缩略图异常**：删除 `~/Library/Application Support/Cap/History/index.json` 后重启，会从 `images/` 重建索引。
