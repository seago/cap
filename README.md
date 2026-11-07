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
