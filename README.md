# Cap

macOS 菜单栏常驻的截图工具。设计稿见 `DESIGN.md`，实施记录见 `.scratch/cap-v1/`。

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
- **设置**：保存目录、PNG/JPEG 格式、登录自启；历史最多保留 100 张（自动删最旧）
- **滚动长截图（v1.1）**：⌘⇧7 框选可滚动区域，自动滚动并拼接成长图；Esc 中止
- **OCR（v1.1）**：历史窗口右键「识别文字」，本地 Vision 识别中英文并复制文本
- **贴图钉屏（v1.1）**：编辑器 ⌘T 或历史右键「贴到屏幕」把截图钉成浮窗；拖动移动、滚轮缩放、双击复位、Esc 关闭、右键复制/点击穿透；⌥⌘P 全局切换穿透

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
