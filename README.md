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

## 数据位置

- 历史：`~/Library/Application Support/Cap/History/`（`index.json` + `images/` + `thumbs/`）
- 保存：默认 `~/Pictures/Screenshots/`，可在菜单栏 popover 中修改
