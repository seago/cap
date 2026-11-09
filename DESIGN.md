# Cap · macOS 截图工具设计与实现方案

> 状态：第 4 轮访谈后的方案稿。产品决定已锁定，工程细节里还有 5 个默认值需要你确认（见 §11）。
> 日期：2026-11-08 · 工作目录：`/Users/bruce/work/screenshot`
> 访谈记录：`.grill/answers-round1.json` … `.grill/answers-round4.json`
> [English version](DESIGN.en.md)

---

## 0. 一页结论

- **Cap** 是一个菜单栏常驻、快捷键驱动的 macOS 截图工具。核心路径只有一条：**⌘⇧2 → 框选 / 点窗口 → 就地标注 → Enter 复制、⌘S 保存**。
- 技术栈：**Swift 6 + SwiftUI（面板 / 设置）+ AppKit（覆盖层 / 画布）+ ScreenCaptureKit 单帧截图 + Carbon 全局快捷键**，无 App Sandbox，Xcode 工程。
- v1 范围：区域 / 窗口 / 全屏（跨屏）、标准矢量标注、剪贴板、手动保存、100 张自动历史、菜单栏设置、登录自启。
- 不做（v1）：滚动长截图、OCR、贴图钉屏、上传、录屏、延时截图 —— 排进 v1.1+，架构上留好接缝。
- 状态（2026-11-09）：v1.1 已实现滚动长截图、OCR、贴图钉屏与自定义快捷键；上传/分享仍待做。详见 §7 M4 与 §10。
- 估算：M0–M3 约 **5.5–8.5 个专注工作日**（不含 App 图标设计与 v1 之后能力）。
- 最大的一处技术取舍：**最低系统版本建议从 macOS 14 提到 15.2**，以使用支持跨屏的 `SCScreenshotManager.captureImage(in:)`。若坚持 14，需要加一条按屏幕分别截取再合成的回退路径。

---

## 1. 定位与边界

### 1.1 用户与场景

给自己每天用的工具，不做公开产品。典型使用：在任意 App 里突然需要一张带箭头/文字的图，发给同事或贴进文档；一天 5–20 次。评价标准是**顺手**，不是功能多。

### 1.2 核心路径

1. 任意上下文按 **⌘⇧2**，所有屏幕进入选区模式。
2. 鼠标悬停的窗口高亮；**拖动 = 区域，单击 = 窗口，空格 = 切换窗口/区域，Enter = 鼠标所在屏全屏，Esc = 取消**。
3. 松手即截取；原图立即可粘贴（剪贴板），选区定格为浮动编辑面板，屏幕其余部分保持实时。
4. 就地标注；**Enter = 复制标注版并关闭；⌘S = 保存标注版并关闭；Esc = 关闭并保留原图**。
5. 这张图自动进入历史；需要找回时从菜单栏打开。

### 1.3 v1 范围

| 包含 | 不包含（v1.1+） |
|---|---|
| 区域选择（任意方向、跨屏、1px 精度） | 滚动长截图 |
| 窗口选择（悬停高亮、单击、默认带阴影） | OCR / 文字识别 |
| 全屏（鼠标所在屏） | 贴图钉屏 |
| 多显示器（所有屏覆盖、跨屏拖选） | 上传 / 分享（v1.1 已完成：自定义 HTTP 端点） |
| 标注：裁剪、矩形、箭头、直线、文字、画笔、高亮、马赛克/模糊、序号、撤销/重做 | 录屏 / GIF |
| 三色（红/黄/蓝）+ 线宽滑块 + 系统字体 | 延时截图 |
| 剪贴板（PNG + TIFF）；标注后覆盖 | 完整样式面板、取色器、椭圆 |
| 手动保存 PNG / JPEG 到固定目录，冲突自动加序号 | 历史「重新编辑」 |
| 自动历史 100 张：预览、复制、Finder 显示、删除 | 云同步、账号、分析埋点 |
| 菜单栏 popover：最近截图、权限状态、快捷键、保存设置、开机自启 | App Store 分发 / 自动更新 |
| 首次启动权限引导、权限失效提示 | 国际化（v1 中文 UI；v1.1 已支持 zh-Hans / en / zh-Hant） |
| 登录自启；`.app` 安装到 `/Applications` | |

### 1.4 完成定义

- **连续 7 天、每天至少 5 次**真实使用；期间发现的问题进 backlog，不阻塞 v1 收尾。
- 关键路径清单（见 §8.2）全部通过。
- 不允许「必须开着 Xcode 才能用」；必须已装进 `/Applications` 并登录自启。

---

## 2. 已锁定的决定

| # | 决定 | 结论 |
|---|---|---|
| 1 | 产品定位 | 自用工具；代码按可产品化标准写，不背商业指标 |
| 2 | 差异化主轴 | 快 + 就地标注（不是长截图 / OCR / 美化 / 工作流） |
| 3 | 技术栈 | 原生 Swift 6；最低 macOS 14（待确认是否提到 15.2） |
| 4 | 触发形态 | 菜单栏常驻 + 自绘全屏选区层 |
| 5 | 截后体验 | 立即复制到剪贴板 + 浮出轻量编辑面板 |
| 6 | v1 范围 | 标准 v1；滚动 / OCR / 贴图 / 上传进 v1 之后 |
| 7 | 选区交互 | 单快捷键 + 智能悬停；拖拽区域、单击窗口、空格切换 |
| 8 | 编辑容器 | 选区旁的浮动工具条（就地编辑） |
| 9 | 工具集 | 标准组：精简组 + 直线、高亮、马赛克/模糊、序号 |
| 10 | 保存策略 | 复制 + 手动保存；⌘S 直接落盘不弹窗 |
| 11 | 历史 | 应用内自动历史库（含未保存的截图） |
| 12 | 工程形态 | Xcode 项目 + 本机运行；bundle id 固定 |
| 13 | 多屏 | 覆盖所有屏幕 + 跨屏拖选 |
| 14 | 编辑时机 | 选区冻结、其余屏幕实时 |
| 15 | 撤销模型 | 矢量操作栈；v1 不支持选中后修改 |
| 16 | 快捷键 | 默认 ⌘⇧2 |
| 17 | 首次授权 | 首次启动引导授予屏幕录制权限 |
| 18 | 开发顺序 | 纵切：全屏截图 → 选区 → 编辑 → 历史/收尾 |
| 19 | 名字 | Cap（bundle id `dev.bruce.cap`） |
| 20 | 标注默认样式 | 系统质感：红/黄/蓝 + 线宽滑块 + 系统字体 |
| 21 | 历史保留 | 最近 100 张，自动清理 |
| 22 | 设置形态 | 菜单栏下拉面板，不做独立设置窗口 |
| 23 | 交付 | 打包 `.app` 放 `/Applications` + 开机自启 |
| 24 | 完成定义 | 连续一周日常使用 |

---

## 3. 交互规格

### 3.1 触发

- 全局快捷键默认：截图 **⌘⇧2**、滚动长截图 **⌘⇧7**、贴图穿透切换 **⌥⌘P**，均可在菜单栏 popover 里录制修改。
- 机器上目前没有第三方截图工具，系统占用 ⌘⇧3 / 4 / 5 / 6；所以滚动截图选 ⌘⇧7（避开系统截图与 Touch Bar 截图）。
- 选区层已打开时再按一次快捷键 = 取消，回到 idle。
- 权限缺失时：不进入选区，菜单栏图标变为警示态并弹出权限提示。

### 3.2 选区层

所有 `NSScreen` 各铺一个无边框透明窗口（`sharingType = .none`），共享一个 `SelectionModel`，坐标用全局屏幕坐标。每个窗口只画自己屏幕内的那部分。

| 操作 | 行为 |
|---|---|
| 热键 | 进入选区层；鼠标所在屏为初始焦点 |
| 鼠标移动 | 十字准星；窗口模式下高亮光标下窗口 |
| 按下并拖动 > 3pt | 区域选择；实时尺寸标签 |
| 单击（位移 < 3pt） | 截取光标下窗口 |
| 空格 | 在「区域」和「窗口」模式之间切换 |
| Enter | 截取鼠标所在整块屏幕 |
| Esc | 取消，回到 idle |
| 松手 | 立即发起截取；成功后关闭覆盖层并进入编辑 |

细节：

- 背景压暗 30%；区域/窗口内提亮，形成「挖洞」效果。
- 尺寸标签贴在选区右下角；不足时翻到上方。
- 不提供放大镜（v1.1）；精确调整交给编辑器的裁剪工具。
- 覆盖层必须能盖住全屏 App 和所有 Space：`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`，窗口层级高于系统状态栏；具体层级在 M1 实测。
- 窗口命中：用 `CGWindowListCopyWindowInfo` 的前后顺序做 z-order，映射到 `SCShareableContent.windows`；排除 Cap 自己的窗口、`windowLayer != 0`、过小或不可见窗口。

### 3.3 截取与冻结

- 松手后**先截取、再关覆盖层、再显示编辑器**；截取失败则保留覆盖层并提示，用户可重试。
- 截取结果立即写剪贴板（原图，PNG + TIFF）。
- 冻结的选区以 1:1 显示在屏幕原位置；其余屏幕保持实时，可切到别的 App，编辑器保持在最上层。
- 编辑器窗口、工具条、覆盖层全部 `sharingType = .none`，避免被截进自己的图里；这是 M1 必须验证的项，失败则回退为「隐藏一帧再截」。

### 3.4 编辑器

形状：选区下方 8pt 处浮出工具条；下方空间不足时翻到选区上方；再不足时贴在屏幕可见区域内。工具条与图分开窗口，工具条不抢焦点。

**工具（标准组，从左到右）**

| 工具 | 交互 | 备注 |
|---|---|---|
| 关闭 | 点击 / Esc | 丢弃标注，保留原图 |
| 裁剪 | 拖出裁剪框，松手应用 | 可撤销；一次裁剪生效 |
| 矩形 | 拖拽 | 描边，无填充 |
| 箭头 | 拖拽，起点为尾、终点为头 | 实心箭头 |
| 直线 | 拖拽 | 2pt 以上线宽 |
| 文字 | 单击定位，就地输入 | 系统字体；Enter 提交，Esc 取消输入 |
| 画笔 | 自由绘制 | 平滑折线 |
| 高亮 | 拖拽矩形 | 半透明黄色，正片叠底 |
| 马赛克 | 拖拽矩形 | 像素化；渲染时对底图区域处理 |
| 序号 | 单击放置 | 圆形底 + 白色数字，自动递增；撤销时回退计数 |
| 撤销 / 重做 | ⌘Z / ⇧⌘Z | 操作栈 |
| 颜色 | 红 / 黄 / 蓝 | 默认红 |
| 线宽 | 2–12 pt 滑块 | 默认 4 |
| 完成 | Enter / 按钮 | 复制标注版并关闭 |
| 保存 | ⌘S / 按钮 | 保存标注版、同步复制、关闭 |

**快捷键**：Enter 完成、⌘C 复制、⌘S 保存、⌘Z 撤销、⇧⌘Z 重做、Esc 关闭（保留原图）、删除键删除最后一条标注（若已聚焦画布）。

**渲染**：所有标注以矢量对象存在，按图像像素坐标保存；导出时以原图像素尺寸渲染，保证 Retina 清晰。v1 不做选中、移动、改属性。

### 3.5 输出

- **剪贴板**：截取时写原图；Enter / ⌘C / ⌘S 后写标注版。格式为 PNG + TIFF，兼容绝大多数 App。
- **保存**：⌘S 直接写文件，不弹对话框；默认目录 `~/Pictures/Screenshots/`，不存在则创建；默认文件名 `Cap 2026-11-08 at 01.30.00.png`；重名自动追加 ` 2`、` 3`。
- **格式**：PNG（默认，无损）/ JPEG（可选，质量 0.85）；在 popover 里切换。
- **反馈**：保存成功在菜单栏图标旁短暂显示对勾；失败保留编辑器并弹错误。

### 3.6 菜单栏与历史

- `NSStatusItem`，图标用 SF Symbol `camera.viewfinder`（模板渲染）；无 Dock 图标（`LSUIElement`）。
- 点击弹出 `NSPopover`：
  - 顶部：权限状态（正常 / 未授权，未授权时显示「去授权」）。
  - 最近截图：2×4 网格，点击复制，右键菜单（复制 / 在 Finder 显示 / 删除）。
  - 「全部截图」：打开历史窗口（720×520）网格，支持预览、复制、在 Finder 显示、删除。
  - 设置区：快捷键录制、保存目录、格式、开机自启、清空历史、退出；界面语言跟随系统（v1.1 三语）。
- 除首次启动引导外，历史窗口是唯一额外窗口；设置仍然只在 popover 内，符合第 4 轮决定。
- 截图完成、复制成功只做轻提示，不弹通知中心。

### 3.7 首次启动与权限

1. 首次启动显示引导窗口（临时把激活策略设为 `.regular` 以显示窗口，完成后切回 `.accessory`）。
2. 文案说明：Cap 需要屏幕录制权限；图片只在本机处理，不联网、不上传。
   - 滚动长截图还需要「辅助功能」权限（自动向目标 App 发送滚动事件）；该权限按需触发系统授权提示，没有时不阻塞普通截图。
3. 主按钮「授予权限」→ `CGRequestScreenCaptureAccess()`；若用户已拒绝过，系统不会再次弹窗，此时打开系统设置深链。
4. 「已授权，重新检测」按钮：重新调用 `CGPreflightScreenCaptureAccess()`；若系统要求重启进程，显示「重新启动 Cap」。
5. 未完成授权时，菜单栏图标保持警示态；热键触发时直接弹权限引导，不进入选区。

### 3.8 错误与空状态

| 情况 | 处理 |
|---|---|
| 权限被拒 / 被撤销 | 引导窗口 + 菜单栏警示；不静默失败 |
| 截取 API 报错 | 保留覆盖层，Toast 提示「截取失败，重试或按 Esc」 |
| 保存失败（目录不可写） | 保留编辑器，提示选择新目录 |
| 快捷键注册失败 | 设置里标红，要求换一个组合 |
| 历史索引损坏 | 扫描图片目录重建索引；无法解析的条目丢弃 |
| 热键冲突（其他 App 占用） | Carbon 不报错也无法可靠检测；录制时对系统保留组合给出警告，其余由用户实测调整 |

---

## 4. 技术基线

### 4.1 工程与平台

| 项 | 决定 |
|---|---|
| 工程 | Xcode 项目（`Cap.xcodeproj`），不用 SwiftPM 打包 |
| 语言 | Swift 6 language mode；AppKit 与 SwiftUI 混用 |
| 最低系统 | 建议 **macOS 15.2**；待确认（理由见 4.2） |
| 目标机器 | macOS 27.2 / arm64；本机即唯一目标机 |
| App 形态 | `LSUIElement = YES`，菜单栏 App，无 Dock |
| Bundle ID | `dev.bruce.cap`（TCC 权限与它绑定，定了不改） |
| 显示名 | Cap |
| 版本 | 0.1.0 |
| App Sandbox | **关闭**（自用、直接读写图片目录、免安全作用域书签） |
| 签名 | 本机自签证书（推荐）；ad-hoc 会导致重建后 TCC 反复授权 |
| 公证 / App Store | v1 不做 |
| 第三方依赖 | 无；快捷键自己封装 Carbon |
| 测试框架 | Swift Testing（`import Testing`） |
| 日志 | `OSLog`，分类 `capture` / `selection` / `editor` / `history` |
| 本地化 | String Catalog（`.xcstrings`），开发语言 `zh-Hans`，语言 `en` / `zh-Hans` / `zh-Hant`，跟随系统 |

### 4.2 本机 SDK 核查（macOS 27.2 SDK，已静态验证）

SDK 根目录：`/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk`

| 事实 | 证据 |
|---|---|
| `SCScreenshotManager` 自 **macOS 14.0** 起可用，仍是单帧截图的正确入口 | `ScreenCaptureKit.framework/Headers/SCScreenshotManager.h:135` |
| `captureImage(contentFilter:configuration:)` 存在，返回 `CGImage`，异步桥接可用 | 同文件 `:153` |
| `captureImage(in:)` 自 **macOS 15.2** 起可用；入参是**跨显示器、与具体屏幕无关的屏幕坐标矩形**，一次拿到跨屏区域 | 同文件 `:161` |
| macOS 26 新增 `SCScreenshotConfiguration` / `SCScreenshotOutput` / `captureScreenshot(rect:configuration:)`，支持直接存 PNG/JPEG/HEIC、HDR、阴影开关；v1 不需要 | 同文件 `:46`、`:118`、`:179` |
| `SCStreamConfiguration.ignoreShadowsSingleWindow`（窗口阴影）与 `ignoreShadowsDisplay` 自 macOS 14 起可用；默认 **包含**阴影 | `SCStream.h:335`、`:340` |
| `showsCursor` 自 macOS 12.3 起可用，默认包含光标；截图时关掉 | `SCStream.h:274` |
| `CGPreflightScreenCaptureAccess()` 自 10.15 起可用，不弹窗，仅查询 | `CoreGraphics.framework/Headers/CGWindow.h:300` |
| `CGRequestScreenCaptureAccess()` 自 10.15 起可用；**已被拒绝的进程不会被再次询问**，必须去系统设置 | 同文件 `:308`、注释 `:295–305` |
| `CGWindowListCreateImage` 已标记 `SCREEN_CAPTURE_OBSOLETE(10.5,14.0,15.0)`，**不用** | 同文件 `:271–274` |
| Carbon `RegisterEventHotKey` 仍存在（HIToolbox，链接符号在 `Carbon.tbd` / `HIToolbox.tbd`）；同一组合在多个进程注册不算错误 | `Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/.../Headers/CarbonEvents.h`、`CarbonEventsCore.h:143–152` |
| `SMAppService.mainApp` 自 macOS 13 起可用，用于登录自启 | `ServiceManagement.framework/Headers/SMAppService.h:91` |
| SwiftUI `MenuBarExtra` 自 macOS 13 起可用；本项目改用 `NSStatusItem`（见 4.8） | `SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface:2378` |
| macOS 14 deployment target 下，`SCScreenshotManager` 的单帧/窗口/屏幕截图 API 在 **Swift 6 mode** 可编译通过 | 探针：`swiftc -typecheck -swift-version 6 -target arm64-apple-macos14.0 -sdk "$(xcrun --show-sdk-path)" /tmp/cap_probe.swift` → 通过 |

**由此产生的版本建议**：把最低版本提到 **15.2**，可以直接用 `captureImage(in:)` 一次拿到跨屏矩形，省掉「每块屏分别截取再拼接」的坐标与 DPI 合成逻辑。如果坚持 14，需要额外实现并测试回退路径（约 40–60 行 + 测试），而目标机本来就是 27.2。**这一点需要你确认。**

### 4.3 采集策略

| 场景 | API |
|---|---|
| 全屏 | `SCContentFilter(display:excludingWindows:)` + `SCStreamConfiguration`（width/height 取 display 像素尺寸）→ `SCScreenshotManager.captureImage` |
| 窗口 | `SCContentFilter(desktopIndependentWindow:)` + 配置；`ignoreShadowsSingleWindow = false`（默认保留阴影）；Option 点击时设 `true` |
| 区域 | **首选** `SCScreenshotManager.captureImage(in: globalRect)`（15.2+）；14 回退为逐屏截取 + 合成 |
| 光标 | `showsCursor = false` |
| 排除自身窗口 | 覆盖层 / 编辑器 / 工具条全部 `NSWindow.sharingType = .none`；M1 实测 SCK 是否遵守。若不遵守，截取前隐藏一帧再恢复 |
| 不用 | `CGWindowListCreateImage`（已 obsolete）、`SCStream`（单帧不需要流） |

### 4.4 坐标与 Retina

- 所有几何换算集中在 `Geometry`：AppKit 左下原点 ↔ CG 左上原点 ↔ 全局屏幕空间 ↔ 图像像素坐标。
- 选区与编辑器面板用 **point**；保存与标注用 **像素**。
- 图像像素尺寸 = 选区宽高 × 对应屏幕的 backingScaleFactor；跨屏混合 DPI 时，以输出图像的像素坐标系为准，缩放比例在 M1 实测后固化。
- 剪贴板写入时保留像素尺寸（`NSBitmapImageRep.size` 设为 point 尺寸），避免粘贴到文档后被意外放大。

### 4.5 全局快捷键

- 自己封装一个约 80 行的 `HotKeyCenter`：`RegisterEventHotKey` + `InstallEventHandler`，不用第三方库。
- 默认组合（2026-11-09 实现）：截图 ⌘⇧2、滚动截图 ⌘⇧7、贴图穿透切换 ⌥⌘P。
- 设置区三行录制控件（`ShortcutRecorderButton`）：点击进入录制，⌫ 恢复默认，Esc 取消；要求至少一个 ⌘/⌥/⌃ 修饰键。
- 录制期间**临时注销所有全局热键**，否则按到已有组合会直接触发原功能而录不到；结束后按当前设置统一重注册。
- 修改后立即重绑并持久化；与其它动作冲突或注册失败时提示并保留原设置。Carbon 不报跨进程冲突，头文件明确「同一组合在多个进程注册不算错误」，冲突只能靠实际使用发现。
- 全局快捷键不需要辅助功能权限，这是它优于 `NSEvent.addGlobalMonitorForEvents` 的地方（但滚动截图的自动滚动需要辅助功能）。

### 4.6 权限

- 启动时 `CGPreflightScreenCaptureAccess()`；不弹窗。
- 引导页按钮调用 `CGRequestScreenCaptureAccess()`；已被拒绝的用户不会被再次询问，直接打开：
  `x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`
- 监听 `NSApplication.didBecomeActiveNotification`，每次回到前台重查权限。
- 辅助功能权限（滚动截图）：首次自动滚动失败且 `AXIsProcessTrusted() == false` 时调用 `AXIsProcessTrustedWithOptions(prompt)`；macOS 27 上在系统设置勾选 Cap 需要管理员密码确认。
- 授权后若 SCK 仍报权限错误，提供「重新启动 Cap」（`NSWorkspace.open` 自身 + `NSApp.terminate`）。
- M0 实测：授权后是否必须重启。不同 macOS 版本行为不完全一致，文档不假设。

### 4.7 签名与 TCC

- TCC 按代码签名身份记录授权；ad-hoc 签名的 designated requirement 可能随重建变化，导致每次改代码都要重新授权。
- 推荐：在钥匙串创建一张自签 **Code Signing** 证书（如 `Cap Local Signing`），Xcode 的 Debug/Release 都用它签名；把 `.app` 放固定路径 `/Applications/Cap.app`。
- 若自签不可行，退而求其次：ad-hoc + 固定 bundle id + 固定路径，接受偶发重新授权；M0 记录实际行为。
- 关闭 Hardened Runtime（本机自用）；将来若公证再开。
- `SMAppService.mainApp.register()` 实现登录自启；要求 App 在 `/Applications` 且签名稳定。

### 4.8 明确不采用

| 方案 | 原因 |
|---|---|
| `CGWindowListCreateImage` | macOS 14 起弃用、15 起 obsolete |
| `SCStream` 抓单帧 | 比 `SCScreenshotManager` 复杂，回调/生命周期成本高 |
| SwiftUI `MenuBarExtra` | 对 popover 行为、权限窗口、全局热键的控制不如 `NSStatusItem` |
| App Sandbox | 自用工具，直接读写图片目录更简单；上架再评估 |
| Electron / Tauri | 采集与权限链路更绕，跨平台无需求 |
| SwiftPM + 脚本打包 | `.app` 的 Info.plist / 签名 / 登录项都要自己拼 |
| 第三方快捷键库 | 需求单一，Carbon 封装 80 行足够，少一个依赖 |

---

## 5. 架构

### 5.1 模块图

```
CapApp (AppDelegate, LSUIElement)
├─ HotKeyCenter            Carbon 全局热键
├─ MenuBarController       NSStatusItem + NSPopover
│   ├─ MenuBarView         SwiftUI：最近截图 / 设置 / 权限
│   └─ HistoryWindow       历史网格（NSPanel + SwiftUI）
├─ CaptureFlowController   状态机与流程编排
│   ├─ PermissionService   preflight / request / 深链
│   ├─ ScreenCaptureService ScreenCaptureKit 封装
│   ├─ WindowIndex         SCShareableContent + CGWindowList 命中测试
│   ├─ SelectionOverlayController  每屏一个覆盖窗口
│   ├─ EditorController    NSPanel + NSView 画布 + SwiftUI 工具条
│   └─ OutputService       剪贴板 / 文件写入
├─ HistoryStore            Application Support + JSON 索引
└─ SettingsStore           UserDefaults
```

### 5.2 目录结构

```
screenshot/
├─ Cap.xcodeproj
├─ Cap/
│  ├─ App/                 CapApp.swift, AppDelegate.swift, AppEnvironment.swift
│  ├─ MenuBar/             MenuBarController.swift, MenuBarView.swift, HistoryWindow.swift
│  ├─ Capture/             ScreenCaptureService.swift, CaptureRequest.swift,
│  │                       WindowIndex.swift, ImageCompositor.swift
│  ├─ Selection/           SelectionOverlayController.swift, SelectionOverlayWindow.swift,
│  │                       SelectionModel.swift, SelectionCanvasView.swift
│  ├─ Editor/              EditorController.swift, EditorCanvasView.swift,
│  │                       EditorToolbar.swift, Annotation.swift,
│  │                       AnnotationRenderer.swift, TextEditingController.swift
│  ├─ Output/              ClipboardWriter.swift, FileExporter.swift, ImageEncoder.swift
│  ├─ History/             HistoryStore.swift, HistoryItem.swift, Thumbnailer.swift
│  ├─ Permissions/         ScreenRecordingPermission.swift, OnboardingWindowController.swift
│  ├─ Settings/            SettingsStore.swift
│  ├─ HotKey/              HotKeyCenter.swift
│  ├─ Support/             Geometry.swift, Logging.swift, FileNaming.swift
│  └─ Resources/           Assets.xcassets, Info.plist
├─ CapTests/               GeometryTests, SelectionStateTests, AnnotationUndoTests,
│                          HistoryRetentionTests, FileNamingTests
└─ DESIGN.md
```

### 5.3 核心类型（草案）

```swift
enum CaptureSource {
    case region(CGRect)               // 全局屏幕坐标（points）
    case window(CGWindowID)
    case display(CGDirectDisplayID)
}

struct CaptureResult {
    let image: CGImage               // 像素坐标
    let scale: CGFloat               // 像素/point
    let capturedAt: Date
}

protocol ScreenCapturing {
    func capture(_ source: CaptureSource, excluding: [CGWindowID]) async throws -> CaptureResult
}

enum SelectionState {
    case idle
    case overlay(SelectionSession)
    case editing(EditorSession)
    case capturing
}

struct SelectionSession {
    var mode: Mode                   // .region / .window
    var dragRect: CGRect
    var hoveredWindow: WindowHit?
}

struct EditorSession {
    let capture: CaptureResult
    var cropRect: CGRect?
    var annotations: [Annotation]
    var undo: [EditorCommand]
    var redo: [EditorCommand]
    var tool: Tool
    var style: AnnotationStyle
}

enum AnnotationKind {
    case rectangle, arrow, line, text(String), pen([CGPoint]),
         highlight, mosaic, number(Int)
}
```

### 5.4 状态机

```
idle
  --hotkey--> permissionGate
permissionGate
  --granted--> indexing (SCShareableContent snapshot)
  --denied--> onboarding
indexing
  --ready--> overlay
overlay
  --drag--> dragging --mouseUp--> capturing
  --clickWindow--> capturing
  --space--> toggle region/window
  --enter--> capturing(displayUnderMouse)
  --esc--> idle
capturing
  --success--> editing
  --failure--> overlay (保留，提示重试)
editing
  --enter/cmdC--> copyAnnotated --> idle
  --cmdS--> saveAnnotated --> idle
  --esc--> keepRaw --> idle
```

### 5.5 数据流

```
hotkey
  → PermissionService.check()
  → SCShareableContent.excludingDesktopWindows(...) 取窗口 + 屏幕
  → SelectionOverlayController 展开覆盖层
  → 用户交点/点击
  → ScreenCaptureService.capture(source)
  → ClipboardWriter.write(raw) + HistoryStore.insert(raw)
  → EditorController.present(frozen image)
  → 用户标注
  → AnnotationRenderer.render(session) -> CGImage
  → ClipboardWriter.write(annotated) / FileExporter.save(annotated)
  → HistoryStore.replace(id, annotated)
```

### 5.6 并发与错误

- UI、控制器、窗口操作全部 `@MainActor`。
- SCK 调用 `async`，结果回到主线程再更新界面。
- 已用探针验证 Swift 6 mode 下 `SCScreenshotManager` 的异步调用可编译；如遇 Sendable 警告，用 `@preconcurrency import ScreenCaptureKit` 收敛，不放宽全局并发检查。
- 自定义 `CapError`（权限、截取、编码、写入、热键注册），菜单栏统一展示，日志保留最近 100 条。

---

## 6. 存储与数据

### 6.1 历史

位置：`~/Library/Application Support/Cap/History/`

```
History/
├─ index.json          // [HistoryItem]，新到旧
├─ images/{uuid}.png   // 原图或标注版
└─ thumbs/{uuid}.jpg   // 320px 缩略图
```

`HistoryItem`：`id`、`createdAt`、`source`、`pixelWidth`、`pixelHeight`、`fileName`、`isAnnotated`。

- 截取成功即插入一条原图记录；编辑器完成（Enter / ⌘S）后把该条替换为标注版并置 `isAnnotated = true`；Esc 保留原图。
- 超过 100 条时删最旧（连同文件）。
- 索引原子写（临时文件 + rename）；启动时校验，损坏则扫描 `images/` 重建。
- 不做云同步、不做埋点。

### 6.2 设置（UserDefaults）

| Key | 默认 |
|---|---|
| `hotKey.<action>.keyCode` / `.modifiers` | 截图 ⌘⇧2、滚动 ⌘⇧7、贴图穿透 ⌥⌘P |
| `saveFolderPath` | `~/Pictures/Screenshots` |
| `imageFormat` | `png`（可选 `jpeg`） |
| `jpegQuality` | 0.85 |
| `launchAtLoginDefaultApplied` | 首次启动自动注册登录项后置 true（实际状态以 `SMAppService` 为准） |
| `historyLimit` | 100（v1 不暴露修改） |
| `cap.accessibilityPrompted` | 滚动截图首次提示过辅助功能权限后置 true |
| `uploadEndpoint` / `uploadFieldName` / `uploadAuthorization` / `uploadResponseURLKey` | 上传端点（默认空 = 未配置）、multipart 字段名（默认 `file`）、可选 `Authorization` 头、可选响应 URL 字段名 |

界面语言不落 UserDefaults：全部文案走 `Localizable.xcstrings`，运行时由系统按「首选语言」自动选择；开发语言是 `zh-Hans`，因此缺失翻译时回退简体中文。

### 6.3 保存

- 文件名：`Cap yyyy-MM-dd 'at' HH.mm.ss.<ext>`；重名追加 ` 2`、` 3`。
- 目录不可写：提示并在设置里换目录，不丢标注。
- 写文件用临时文件 + rename，避免半张图。

### 6.4 隐私

- 无网络请求、无第三方 SDK。
- 图片只在本机内存、剪贴板、历史目录、用户选择的保存目录之间流转。
- 历史可一键清空；菜单栏显示占用空间。

---

## 7. 里程碑

> 估算是「专注工作日」，不是日历天；按纵切顺序推进，每个里程碑都可独立验收。

### M0 · 骨架与全屏截图（0.5–1 天）

- Xcode 工程、`LSUIElement`、菜单栏图标、AppDelegate。
- `HotKeyCenter`（⌘⇧2）+ 录制入口（先写死也行）。
- 权限引导窗口 + preflight / request / 深链 / 重新检测。
- `SCScreenshotManager` 截鼠标所在全屏 → 写剪贴板。
- 历史目录与最小 `HistoryStore`（先存一张）。

**验收**：全新安装 → 引导授权 → 关掉 Xcode → 重启系统 → ⌘⇧2 仍能截图进剪贴板；重建后权限不需要重新授予（否则切自签证书）。

### M1 · 选区层（1.5–2.5 天）

- 多屏覆盖层、压暗、十字准星、窗口高亮、尺寸标签。
- 拖动 / 单击 / 空格 / Enter / Esc；3pt 阈值。
- 区域截取（15.2 跨屏 API）、窗口截取（含阴影）、全屏。
- 排除自身窗口的截图验证；失败则隐藏一帧。
- 截取即进剪贴板 + 历史。
- 权限被撤销、截取失败的错误路径。

**验收**：双屏环境连续 20 次区域 / 窗口截取，输出不含 Cap 自己的 UI；跨屏选区尺寸正确；Esc / 空格 / Enter 行为稳定。

### M2 · 编辑器（2–3 天）

- 冻结面板、就地工具条、边缘翻转。
- 标准组 9 个工具 + 撤销/重做 + 三色 / 线宽。
- 文字输入（含中文输入法）、Retina 导出。
- Enter 复制标注版、⌘S 保存、Esc 保留原图。
- 历史条目替换为标注版。

**验收**：用标准组每个工具各画一次；撤销 10 步回到原图；中文输入正常；导出像素与原图一致；重名保存不覆盖。

### M3 · 产品表面（1.5–2 天）

- popover：最近截图、设置、权限状态、退出。
- 历史窗口：网格、预览、复制、Finder、删除、清空。
- 保存目录选择、格式切换、登录自启。
- 打包 `.app` 到 `/Applications`、图标、首次启动 polish。
- 错误提示、日志、性能检查。

**验收**：装进 `/Applications`、登录自启、连续一周每天用；关键路径清单通过。

**总计**：约 5.5–8.5 个专注工作日；最大不确定性在 M1（覆盖层与截取互斥、混合 DPI）。

### M4 · v1.1（已实现部分，2026-11-09）

| 能力 | 状态 | 关键点 |
|---|---|---|
| 滚动长截图 | ✅ 已验收 | ⌘⇧7 框选 → AXRaise 目标窗口 + HID 滚轮 → 逐帧拼接；需辅助功能权限；吸顶/动态内容可能提前停止（歧义保护，不输出错位图） |
| OCR | ✅ 已验收 | Vision 本地中英识别；历史右键「识别文字」复制并写回 `ocrText` |
| 贴图钉屏 | ✅ 已验收 | 编辑器 ⌘T / 历史右键「贴到屏幕」；拖动/缩放/穿透/关闭；⌥⌘P 全局穿透切换；`sharingType=.none` 不进截图 |
| 自定义快捷键 | ✅ 已验收 | 三个动作可录制；冲突提示；录制期间临时注销热键 |
| 多语言 | ✅ 已验收 | String Catalog：zh-Hans / en / zh-Hant，跟随系统语言；124 个 key；AppKit 字符串走 `String(localized:)` |
| 上传 / 分享 | ✅ 已验收 | 用户自定义 HTTP 端点（multipart `file` 字段 + 可选 Authorization）；成功 URL 进剪贴板并写回历史；`UploadService` 协议可替换；未配置时入口隐藏 |

**验收**：191 项单测 + 实机 liveness（滚动截图、OCR、贴图、录制快捷键、英文界面、上传）；提交记录见 git（`7274185`、`a2cf38c`、`27035f9`、`0d7a8e7`、`30af388`、`67e8407`）。

---

## 8. 测试计划

### 8.1 单元测试

| 测试 | 内容 |
|---|---|
| `GeometryTests` | AppKit ↔ CG 坐标、跨屏矩形、Retina 缩放、屏幕原点 |
| `SelectionStateTests` | 3pt 阈值、空格切换、Enter 目标屏、Esc 重置 |
| `AnnotationUndoTests` | 添加 / 撤销 / 重做、序号回退、裁剪可撤销 |
| `FileNamingTests` | 时间格式、冲突追加、非法字符 |
| `HistoryRetentionTests` | 100 条剪枝、索引损坏重建、替换标注版 |
| `ImageEncoderTests` | PNG / JPEG 尺寸与 DPI 元数据 |

### 8.2 手动测试矩阵

| 维度 | 用例 |
|---|---|
| 显示器 | 内置单屏、1 台外接、2 台外接、混合 Retina/1x、缩放分辨率 |
| 选区 | 四方向拖拽、1px、整屏、跨屏、窗口单击、全屏 App、不同 Space、Stage Manager |
| 权限 | 首次拒绝、系统设置授权、运行中撤销、重启应用、重建 App |
| 快捷键 | ⌘⇧2、被其他 App 占用、睡眠唤醒、用户改键 |
| 编辑器 | 每个工具、10 步撤销、中文输入、贴着屏幕边缘、跨屏选区 |
| 窗口 | 带阴影 / 不带阴影、部分移出屏幕、最小化窗口、全屏窗口 |
| 输出 | 粘贴到备忘录 / 邮件 / Keynote / Finder、Retina 尺寸、PNG/JPEG、重名 |
| 历史 | 第 101 张、删除、清空、索引损坏、重启后保留 |
| 压力 | 连续 50 次截图、内存不增长、热键响应 |

**关键路径清单**：权限 → 热键 → 区域 → 窗口 → 全屏 → 复制 → 标注 → 复制 → 保存 → 历史找回 → 重启后仍可用。

### 8.3 性能目标

- 热键到覆盖层可见：**< 150ms**
- 松手到剪贴板可粘贴：**< 400ms**（6K 区域）
- 空闲内存：**< 200MB**；50 次截图后无持续增长
- 历史 100 张占用：**< 2GB**；缩略图 < 20KB/张

---

## 9. 风险与未知

| # | 风险 | 影响 | 缓解 | 验证 |
|---|---|---|---|---|
| 1 | 重建后 TCC 反复授权 | 每天被打断 | 自签证书 + 固定路径；M0 实测 | M0 |
| 2 | 覆盖层被 SCK 截进图里 | 每张图带灰罩 | `sharingType = .none`；不生效则隐藏一帧再截 | M1 |
| 3 | 混合 DPI 跨屏尺寸不一致 | 图像模糊 / 错位 | 优先 15.2 跨屏 API；逐屏合成回退；M1 实测后固化 | M1 |
| 4 | 非激活面板无法输入文字 | 文字工具不可用 | 选中文字工具时临时 `makeKey`；或改用可激活面板 | M2 |
| 5 | 全屏 App / 多 Space 盖不住 | 无法截图 | `.canJoinAllSpaces` + `.fullScreenAuxiliary`；层级实测 | M1 |
| 6 | Carbon 热键与他 App 冲突 | 无响应或双触发 | 录制器 + 系统保留组合警告；允许随时改 | M0 |
| 7 | 授权后需重启进程 | 首次体验断裂 | 引导页提供「重新启动 Cap」 | M0 |
| 8 | 大图 + 100 张历史占盘 | 磁盘膨胀 | 100 上限、缩略图、清空入口 | M3 |
| 9 | Swift 6 并发与 AppKit 摩擦 | 编译/运行时警告 | 已验证 SCK 探针；MainActor 边界；`@preconcurrency` 收敛 | M0 |
| 10 | 窗口命中顺序不准 | 截错窗口 | 用 CGWindowList z-order；排除自身/非 0 层；实测 | M1 |

---

## 10. v1 之后

建议顺序：**滚动长截图 → OCR → 贴图钉屏 → 上传 / 分享**。
状态（2026-11-09）：前三项已实现并验收；上传待做。

- **滚动长截图**（已实现）：框选区域 → 把目标窗口 AXRaise 到前台 → 逐帧截图 + HID 滚轮事件 → `ScrollStitcher` 特征匹配拼接。实测 Chrome 长页 1100×2625 无错位；`CGEvent.postToPid` 对 Chrome 无效、第一帧滚动偶发被吞，均已在实现中处理（重复帧重试）。限制：吸顶导航/动态内容可能提前停止（宁可停也不输出错位图）。
- **OCR**（已实现）：Vision 的 `VNRecognizeTextRequest`，本地、离线，中英混排；结果直接复制并写回 `HistoryItem.ocrText`。
- **贴图钉屏**（已实现）：无边框 `NSPanel` 显示图片，拖动、滚轮锚点缩放（0.1–8x）、双击复位、Esc 关闭、右键复制/穿透；默认不进截图。
- **上传 / 分享**（已实现）：不内置图床；用户在设置区填自己的 HTTP 端点，历史右键「上传并复制链接」或编辑器上传按钮触发；multipart POST，响应解析 JSON `url`/`link`/`data.url` 或纯文本 URL；成功后链接进剪贴板并写回 `HistoryItem.uploadedURL`。`UploadService` 协议 + `UploadCoordinator` 隔离网络逻辑，截图/编辑器流程只拿结果。
- **架构接缝**：`OutputService` 已经是可替换的出口；`HistoryItem` 预留 `ocrText` 字段；编辑器渲染器与采集解耦，贴图可直接复用渲染结果。

---

## 11. 已确认的 5 个默认值

状态：已确认（2026-11-08）

已在方案里按以下结论落地：

1. **最低系统版本**：建议从 14 提到 **macOS 15.2**，直接用跨屏单次截取 API；坚持 14 就加逐屏合成回退。
2. **窗口截图默认带阴影**：单击窗口直接带阴影/圆角；按住 Option 点击则不带。是否符合你的习惯？
3. **原始版 / 标注版的关系**：截图即复制原图并进历史；Enter / ⌘S 用标注版覆盖剪贴板与历史；Esc 保留原图。是否接受「历史里只留最终版」？
4. **保存默认值**：`~/Pictures/Screenshots/`、`Cap 2026-11-08 at 01.30.00.png`、PNG 默认、JPEG 可选。是否要改成桌面或别的命名？
5. **v1 之后的顺序**：滚动 → OCR → 贴图 → 上传。是否同意？如果更想要 OCR 或贴图先上，直接说。
   - 状态（2026-11-09）：滚动 / OCR / 贴图已完成并验收，上传待做。

确认之后，就可以从 **M0（骨架 + 全屏截图 + 权限/签名验证）** 开工。

---

## 附录 A · 访谈答案

| 轮次 | 文件 |
|---|---|
| 第 1 轮 | `.grill/answers-round1.json` |
| 第 2 轮 | `.grill/answers-round2.json` |
| 第 3 轮 | `.grill/answers-round3.json` |
| 第 4 轮 | `.grill/answers-round4.json` |

页面源码：`.grill/round1.html` … `.grill/round4.html`；本地服务 `server.py`（当前 `http://127.0.0.1:47921/round4.html`，仅在运行时可用）。

## 附录 B · SDK 核查命令

```bash
SDK=$(xcrun --show-sdk-path --sdk macosx)
# 关键声明
grep -n "SCScreenshotManager\|captureImageInRect" \
  "$SDK/System/Library/Frameworks/ScreenCaptureKit.framework/Headers/SCScreenshotManager.h"
grep -n "ignoreShadowsSingleWindow" \
  "$SDK/System/Library/Frameworks/ScreenCaptureKit.framework/Headers/SCStream.h"
grep -n "PreflightScreenCaptureAccess\|RequestScreenCaptureAccess\|SCREEN_CAPTURE_OBSOLETE" \
  "$SDK/System/Library/Frameworks/CoreGraphics.framework/Headers/CGWindow.h"
# 编译探针（macOS 14 目标 + Swift 6 mode）
swiftc -typecheck -swift-version 6 -target arm64-apple-macos14.0 -sdk "$SDK" /tmp/cap_probe.swift
```

> 注：以上是静态 SDK 核查 + 编译探针。TCC 重启行为、覆盖层是否被截入、混合 DPI 的实测结论，会在 M0 / M1 用运行结果替换本节的「待验证」判断。
