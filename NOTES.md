# Cap 项目笔记

> loop-me session 的 raw notes：用户世界、工具、渠道、canonical terms。
> 不是 spec；spec 在 `workflows/`。

## 用户世界

- 单人开发；目标机器 macOS 27.2 / arm64；v1 只做中文 UI
- 产品：菜单栏常驻的截图工具，自用，不做公开产品
- 代码：Swift 6 + SwiftUI / AppKit，Xcode 工程 `Cap.xcodeproj`，无第三方依赖
- 测试：Swift Testing 单测 + 依赖 GUI / TCC 的手动矩阵
- 仓库：`/Users/bruce/work/screenshot`；GitHub private `seago/cap`（origin，SSH），`main` 直推
- Git 身份：`yufeng108 <yufeng108@qq.com>`
- Issue tracker：本地 markdown，`.scratch/cap-v1/issues/`
- 工作环境：DSH Web session；由用户发起 run
- 记录：每步一个 commit，message 含功能点 / 文件 / 验证；每次 run 的要点追加到 ticket `## Runs`

## Canonical terms

| Term | 含义 |
|---|---|
| run | 一个连续工作块；只处理一个 ticket，产出一个 commit |
| ticket | `.scratch/cap-v1/issues/NN-slug.md` 中的一个工作项 |
| ready ticket | `Status: ready-for-agent` 且 `Blocked by` 全部 `done` |
| auto / manual | 验收项能否由 agent 自动验证 |
| brief | run 或 planning 结束时给用户的 decision-ready 摘要 |
| checkpoint | 用户看 brief、做决定的点；不阻塞 commit |
| blocked | 同一阻塞点 3 次无进展，或环境不可用 |
| awaiting-manual | 代码与 auto 已完成，agent 无法验证的 manual 项等待用户验收 |
| computer verification | agent 用截图 / 系统查询 / Apple Event 代替用户做 GUI 验收 |
| milestone 验收 | `.scratch/cap-v1/milestones.md` 中逐项勾选，全部通过才拆下一个 milestone |

## 当前状态

- `DESIGN.md` §11 已确认（2026-11-08）
- 尚未创建 Xcode 工程；本机 `security find-identity` 显示 0 个 codesigning 身份
- `origin/main` 与本地同步，工作区干净
- `workflows/cap-planning.md` 与 `workflows/cap-implementation.md` 已落地

## 已确认的默认值

- §11.1 最低系统 **macOS 15.2**
- §11.2 窗口默认带阴影；Option 点击不带
- §11.3 历史只留最终版
- §11.4 `~/Pictures/Screenshots/` + `Cap YYYY-MM-DD at HH.mm.ss.png`；PNG 默认
- §11.5 v1 之后：滚动 → OCR → 贴图 → 上传

## 实施前置

- `Cap.xcodeproj` 需手工生成（本机无 xcodegen / tuist）
- #06 需要自签 codesigning 证书；当前 0 个身份，Keychain 交互可能需用户确认
- TCC 与签名绑定：ad-hoc 每次重建失效（#04 实测）；已创建自签身份 `Cap Local Signing`，TCC 重新授权一次后应稳定
- 顺序调整：#06 先于 #05，避免每次重建都重新授权 TCC

## 环境注意

- 本 shell 的 `DEVELOPER_DIR` 指向过期的 CommandLineTools，所有 `xcodebuild` 需前缀
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
- 单显示器环境：M1 的跨屏/多屏验收项需记 `Deferred`

## Computer verification

- `screencapture` 可用；屏幕 1920x1200 @1x（单屏，无双显示器）
- Accessibility **已授权**（macOS 27 面板名为「设备控制和数据访问」）：CGEvent 合成点击、System Events 按键可用
- `cliclick` 未安装；`lsappinfo` 可用；Apple Event quit 可用
- 菜单栏 Cap 图标位置约 x=1436-1448、y=8-22（截图 diff 证据）
- Cap 自己的屏幕录制权限（TCC）只能由用户在系统设置里授予
- 屏幕录制 TCC 已对 `dev.bruce.cap` 授权，且随固定签名保持（重建不失效）

## 实现笔记（v1 → v1.1，2026-11-09）

### 环境 / 构建

- 本机 `DEVELOPER_DIR` 是过期的（指向 Android SDK 里的 CommandLineTools）；所有 `xcodebuild` 都要加前缀
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`。
- Release / `Scripts/install.sh` 产物是 Universal（arm64 + x86_64）；Debug 默认 `ONLY_ACTIVE_ARCH=YES`，只编本机架构。
- 用 `Scripts/install.sh` 安装到 `/Applications/Cap.app`；TCC 依赖稳定的自签身份 `Cap Local Signing`，ad-hoc 重建会丢授权。
- 截图验证编辑器/钉屏时用 `CAP_EDITOR_CAPTURABLE=1` 启动（两者默认 `sharingType=.none`，不进入 screencapture）。

### 权限（macOS 27）

- 屏幕录制：`CGPreflightScreenCaptureAccess()` + 引导页深链；授权后一般不需要重启进程。
- 辅助功能：滚动截图自动滚动必需；首次失败时 `AXIsProcessTrustedWithOptions(prompt)` 弹系统提示，
  在系统设置勾选 Cap 时 macOS 27 会要求**管理员密码**确认（不是点一下就行）。
- 自动化验收时注意：锁屏会拦截合成键鼠事件；菜单栏 popover/history 等普通窗口可用 AX 操作，但目标 App 前台时 Esc 需要全局 monitor。

### 技术坑（都已在代码里处理）

- Carbon 多热键：多个 `InstallEventHandler` 时，不匹配的事件必须返回 `eventNotHandledErr`；
  返回 `noErr` 会吞掉其它实例的热键事件（表现为后加的热键生效、旧的失效）。
- `CGEvent.postToPid` 对 Chrome 不生效；滚动截图改 HID tap 滚轮 + `CGWarpMouseCursorPosition`。
- 用户正在别的 App 操作时，后台 App 的 `NSRunningApplication.activate` 会被忽略；改用 AXRaise 目标窗口。
- 第一帧后的滚动偶发被吞：丢弃重复帧重试（最多 3 次）。
- NSPopover 写死 `contentSize` 且与 SwiftUI 实际内容高度不一致时，窗口按左下角收缩，顶部会往下掉；
  用 `NSHostingController.sizingOptions = [.preferredContentSize]` + show 前同步尺寸。
- 钉屏窗口的 `performDrag` 在非激活面板里拖不动；改手动算 delta 移动窗口。
- 滚轮缩放要区分 `hasPreciseScrollingDeltas`（触控板 delta 小、滚轮 delta 大），否则一次滚动直接到 8x。
- 菜单栏图标默认被 screencapture 截到；Cap 自己的覆盖层/编辑器/钉屏都设 `sharingType=.none`。

### 快捷键

| 动作 | 默认 | UserDefaults key |
|---|---|---|
| 截图 | ⌘⇧2 | `hotKey.capture.keyCode/.modifiers` |
| 滚动长截图 | ⌘⇧7 | `hotKey.scrollCapture.*` |
| 贴图穿透切换 | ⌥⌘P | `hotKey.pinClickThrough.*` |

- 存的是 Carbon keyCode + modifiers（cmdKey=256、shiftKey=512、optionKey=2048、controlKey=4096）。
- 录制期间临时注销全部全局热键，结束后按当前设置重注册；冲突/注册失败保留原设置并提示。

### 本地化（v1.1）

- 开发语言是 `zh-Hans`：源码里的中文字面量同时是 key；`en` / `zh-Hant` 翻译在 `Cap/Resources/Localizable.xcstrings`。
- SwiftUI `Text` / `Button` 的字面量由 String Catalog 自动提取；AppKit 可见字符串必须用 `String(localized: "...")`。
- 新增/修改文案后先 build，再跑
  `xcodebuild -project Cap.xcodeproj -exportLocalizations -localizationPath /tmp/loc -exportLanguage en`
  让 Xcode 把新 key 写进 catalog，然后补翻译（catalog 里 `%lld` / `%@` 占位符数量必须与中文 key 一致）。
- 运行时资源是编译后的 `en.lproj/Localizable.strings` 与 `zh-Hant.lproj/Localizable.strings`；`zh-Hans` 不生成 lproj，直接回退 key（中文）。
- 验证语言：`Cap.app/Contents/MacOS/Cap -AppleLanguages '(en)'`；也可以通过 `defaults write dev.bruce.cap AppleLanguages -array en`。
- `LocalizationTests` 锁住三语言资源存在、关键 key 翻译、占位符一致性；GUI 手动项待系统语言切换实测。

### 上传（#31）

- 配置存 UserDefaults：`uploadEndpoint` / `uploadFieldName` / `uploadAuthorization` / `uploadResponseURLKey`；未配置时历史右键菜单项隐藏、编辑器上传按钮提示先配置。
- multipart 字段名默认 `file`，文件整体一次 POST；`Authorization` 头可选（明文存 UserDefaults，只建议短期 token）。
- 响应解析顺序：自定义字段名 → `url` / `link` / `imageUrl` / `data.url` / `data.link` → 纯文本 URL；以上都没有则报「上传结果不是有效链接」。
- 重试策略：超时/网络错误/5xx 重试 1 次；4xx 直接报错（鉴权/配置问题重试无意义）。
- 本地验收：`python3 Scripts/mock-upload-server.py --port 8765 --dir /tmp/cap-uploads`，然后设置端点 `http://127.0.0.1:8765/upload`；脚本会把上传文件存到 --dir 并返回 JSON。
- 成功路径：URL 复制到剪贴板 + 写回 `HistoryItem.uploadedURL`（卡片显示「· 已上传」）；失败只提示，不动历史。

### 发布 / CI（GitHub Actions）

- `.github/workflows/release.yml`：push `v*` tag 或手动 Run workflow → 先跑单测，再 `Scripts/make-release.sh <版本>`（ad-hoc 签名），最后 `gh release create`。
- macOS runner 用 `macos-26`（默认 Xcode 26.x，Swift 6.3+）；本机是 Xcode 27.2 / Swift 6.4，最初的 `macos-15`（Xcode 16.x）在编译 CapTests 时报错，升级 runner 对齐工具链。CI 测试/构建失败时 workflow 会 grep 出 `error:` 行并上传完整日志 artifact。
- 私有仓库：Release 仅 collaborator 可见；Actions 用量 macOS runner 按 10 倍分钟计费。
- CI 里没有本机自签身份 `Cap Local Signing`，用 `CODE_SIGN_IDENTITY=-`（ad-hoc）；用户下载后需右键打开/去 quarantine。
- 发布产物同时出 **dmg**（`hdiutil create -format UDZO`，内含 Cap.app + `/Applications` 软链）和 **zip**（`ditto -c -k --keepParent`），两者都附 SHA256；dmg 是给人拖拽安装，zip 给脚本/更新用。
- workflow 幂等：Release 已存在时 `gh release edit` 更新说明 + `gh release upload --clobber` 覆盖附件。
- 正式对外分发需要 Developer ID + `notarytool` 公证 + `stapler staple`；当前不做。
- 版本号来源：`Cap.xcodeproj` 的 `MARKETING_VERSION`（当前 0.1.0）；tag 用 `v<版本>`。
