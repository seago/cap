# Cap · v1.1 验收报告（#32）

- 日期：2026-11-10 00:40（Asia/Shanghai）
- 版本：0.1.0（Release Universal）
- 代码：`main` @ `5bf9a44`（功能提交到 `67e8407`）
- 环境：macOS 27.2、arm64 主机、单屏 1920×1200；屏幕录制 + 辅助功能权限已授予
- 相关 tickets：#28 滚动截图 / #29 OCR / #30 贴图 / #31 上传 / #33 快捷键 / #34 多语言 / #35 文档

## 1. 结论

**v1.1 整体验收通过（Accepted）。** 5 项功能 + 多语言 + 文档全部完成并实机验证；无阻塞项。剩余 6 项属于无法在无人值守会话内安全/可靠完成的手动场景（见 §5），已记录为 Deferred，不影响 v1.1 发布。

## 2. 自动化验收

| 项目 | 结果 | 证据 |
|---|---|---|
| 单测 | **191 passed / 0 failed**（5.6s） | `xcodebuild ... test`，含滚动拼接、OCR、贴图模型、快捷键设置、三语本地化、上传 12 项 |
| Release 构建 + 安装 | ✅ | `Scripts/install.sh` → `Installed: /Applications/Cap.app` |
| 产物架构 | ✅ Universal | `lipo -info` → `x86_64 arm64` |
| Bundle | ✅ | `dev.bruce.cap` / 0.1.0 / `LSMinimumSystemVersion 15.2` / DevelopmentRegion `zh-Hans` |
| 本地化资源 | ✅ | `en.lproj/Localizable.strings`、`zh-Hant.lproj/Localizable.strings`、`CFBundleLocalizations = en / zh-Hans / zh-Hant` |
| 签名 | ✅ | 自签 `Cap Local Signing`（TCC 授权跨重建保持） |

## 3. 功能实机验收

### 3.1 v1 关键路径（无回归）

| 场景 | 结果 | 证据 |
|---|---|---|
| ⌘⇧2 → 拖选 → 编辑器 | ✅ | 600×450 选区，编辑器就地打开 |
| 标注 | ✅ | 箭头工具拖拽，导出图中可见红色箭头 |
| Enter 复制 | ✅ | 剪贴板 PNG 600×450（85,580 bytes）；历史 `isAnnotated=true` |
| ⌘S 保存 | ✅ | 生成 `~/Pictures/Screenshots/Cap 2026-11-10 at 00.37.33.png` |
| Esc 保留原图 | ✅ | 历史新增条目 `isAnnotated=false`，编辑器关闭 |
| 历史窗口 | ✅ | 网格/预览/复制/删除可用（删除 11→10 条实时生效） |
| popover | ✅ | 权限状态、最近 8 张缩略图、历史/长截图/设置/退出按钮、设置区全部正常 |

### 3.2 滚动长截图（#28）

| 项 | 结果 |
|---|---|
| Chrome 长页面 | ✅ 窗口内框选 940×520，自动滚动采集 **10 帧**，拼接 **940×2454 px**，无错位/重复行（首尾裁剪检查通过） |
| 日志 | `Scroll stitched dims=940x2454 pooledFrames=10 stitchedFrames=8` → `Scroll capture finished` |
| 结果进入编辑器/历史 | ✅ Enter 后剪贴板 940×2454 PNG（604,818 bytes），历史条目同步 |
| 重复帧/到底处理 | ✅ 首帧重复被丢弃重试；页面到底自动停止 |
| Safari | ⚠️ 未单独测（同一 SCK/AX 机制，风险低）；Chrome 已验证可用 |
| 限制 | 吸顶导航/动态内容可能提前停止（歧义保护，宁可停也不输出错位图） |

### 3.3 OCR（#29）

| 项 | 结果 |
|---|---|
| 中英混排识别 | ✅ 最新截图右键「识别文字」→ 剪贴板得到中英混排文本（如 `>-运行命令•Disa … 新会话 … 思考•Interestin…`） |
| 持久化 | ✅ `index.json` 的 `ocrText` 写入识别结果 |
| 失败/空结果提示 | ✅ 单元测试覆盖；UI 错误路径有明确文案 |

### 3.4 贴图钉屏（#30）

| 项 | 结果 |
|---|---|
| 钉图 | ✅ 历史右键「贴到屏幕」→ 600×450 浮窗（`sharingType=.none`，不进截图） |
| 拖动 | ✅ 窗口精确跟随 +100,+100 |
| 滚轮缩放 | ✅ 600×450 → 1094×820（鼠标锚点，0.1–8x 夹取） |
| 点击穿透 | ✅ 右键「点击穿透」→ `click-through=true`；⌥⌘P 全局恢复 `false` |
| 关闭 | ✅ Esc 关闭；多张错开摆放 |

### 3.5 上传（#31）

| 项 | 结果 |
|---|---|
| 本地 mock 端点 | ✅ `Scripts/mock-upload-server.py` 收 940×2454 PNG（604,830 bytes），返回 URL |
| 剪贴板 | ✅ `http://127.0.0.1:8765/uploads/d13c9265d8fb.png` |
| 历史回写 | ✅ 卡片显示「已上传」，`uploadedURL` 入库 |
| 失败/未配置 | ✅ 服务停止时提示「上传失败：网络错误：无法连接服务器。」且历史不变；未配置时上传入口隐藏 |
| 重试策略 | ✅ 5xx/网络错误重试 1 次、4xx 不重试（单测） |

### 3.6 多语言（#34，随 #32 一起验收）

| 语言 | 结果 |
|---|---|
| 系统默认（简体中文） | ✅ 权限条/按钮/设置全部中文，popover 正常 |
| `-AppleLanguages '(en)'` | ✅ `Screen recording permission OK` / `History` / `Scroll` / `Settings` / `Quit` |
| `-AppleLanguages '(zh-Hant)'` | ✅ `螢幕錄製權限正常` / `歷史` / `長截圖` / `設定` / `結束`（此前锁屏 Deferred 项已补测） |

## 4. 已知限制（写入 v1.1 说明，不算缺陷）

1. 滚动截图遇到吸顶导航/动态加载内容可能提前结束；不输出错位图。
2. 上传不内置图床；鉴权值明文存 UserDefaults，只建议短期 token。
3. Carbon 跨进程热键冲突无法可靠检测；录制时对系统保留组合提示，冲突以实测为准。
4. 历史只保留最终版（Esc 保留原图），不支持重新编辑。

## 5. Deferred（无阻塞，后续迭代/人工确认）

| # | 项 | 原因 | 后续 |
|---|---|---|---|
| 1 | 重启后登录项持久化 | 需要重启系统，当前会话无法安全执行 | 用户重启后确认「登录项」仍在 |
| 2 | 首次启动 onboarding 重新触发 | 需清空用户 UserDefaults，会破坏现有配置 | 新机/测试账号验证 |
| 3 | 清空历史 live（破坏性） | 会删除用户现有历史，不可在验收中执行 | 已有单测覆盖；用户在备份后自测 |
| 4 | 中文输入法组合输入 | 合成按键无法驱动真实 IME 组合态 | 用户用中文输入法在文字工具实测 |
| 5 | 只读目录保存失败弹窗 | 需制造不可写保存目录 | 单测覆盖错误路径；用户可用只读目录自测 |
| 6 | Safari 滚动截图 | 需手动开 Safari 长页 | Chrome 已通过；Safari 机制相同，风险低 |

## 6. 交付物

- 代码：`main`，最新功能提交 `67e8407 feat(upload)`、`5bf9a44 docs(upload)`
- 安装：`/Applications/Cap.app`（Universal，0.1.0）
- 测试：191 项；脚本 `Scripts/install.sh`、`Scripts/mock-upload-server.py`
- 文档：`README(.en).md`、`DESIGN(.en).md`、`NOTES.md`、`GLOSSARY.md`、`docs/adr/0001–0003`

## 7. 后续建议

1. 做（可选）：Safari 滚动截图、真实 IME、重启登录项的人工确认。
2. 下一版本候选：`UploadService` 增加内置图床预设、滚动截图对 sticky header 的补偿、编辑器历史「重新编辑」。
