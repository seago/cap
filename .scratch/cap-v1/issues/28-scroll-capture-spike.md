# 28 · 滚动长截图（spike → 是否进 v1.1）

Milestone: M4
Status: awaiting-manual
Blocked by:
Type: spike

## Goal

按 DESIGN §10：滚动长截图最难，先做 spike 验证「自动滚动 + 帧拼接」是否可靠，输出 go/no-go 结论；go 则同一 ticket 内落成可用功能。

## Decision criteria（go）

- 在 Safari/Chrome 的普通长网页上，连续滚动 5+ 屏后拼接结果 ≥ 95% 内容正确，无明显错位/重复带
- 不需要用户手动滚动（自动滚动），Esc 可中止
- 上限 10 屏，失败时明确提示而不是输出坏图
- 已知限制写清楚：吸顶导航/吸底栏/横向滚动/无限加载

## Acceptance

- [x] [auto] `ScrollStitcherTests`：合成滚动帧（含重叠区 + 内容）拼接后与完整长图逐像素一致或近似一致
- [x] [auto] 重叠检测对无重叠/反向滚动/完全相同帧有安全行为
- [x] [auto] build + 既有测试通过
- [ ] [manual] Chrome/Safari 长页面滚动截图成功；Esc 中止；结果进编辑器
- [ ] [manual] 吸顶导航等限制场景不产生破损图（提示或截断）

## Scope

In:

- `Cap/Scroll/ScrollStitcher.swift`（纯算法，可注入帧）
- `Cap/Scroll/ScrollCaptureController.swift`（自动滚动 + 逐帧截图 + 拼接）
- `Cap/Scroll/ScrollCaptureOverlay.swift`（进度/取消）
- 菜单栏 popover「滚动截图」入口 + 快捷键 ⌘⇧3（新增全局热键）
- 结果进编辑器（复用 EditorController）

Out:

- 横向滚动拼接、无限加载页面、滚动中动态内容（v1.2 视结论）

## Files

- `Cap/Scroll/ScrollStitcher.swift`
- `Cap/Scroll/ScrollCaptureController.swift`
- `Cap/Scroll/ScrollCaptureOverlay.swift`
- `Cap/HotKey/HotKeyCenter.swift`
- `Cap/MenuBar/MenuBarPopoverView.swift`
- `Cap/App/AppDelegate.swift`
- `CapTests/ScrollStitcherTests.swift`
- `Cap.xcodeproj/project.pbxproj`

## Notes

- 拼接用 Vision `VNTranslationalImageRegistrationRequest` 或 NCC 相关；需要处理相邻帧固定高度重叠
- 自动滚动通过 `CGEvent` scroll wheel 事件 + `CGEventPostToPid`/HID tap；需要 Accessibility 权限（需在引导与错误提示中说明）
- 失败路径必须比成功路径更清楚：内容没动、滚动到底、权限缺失、窗口不可滚动

## Runs

### 2026-11-09 17:40 · run 1（spike 代码完成）

- Auto: `ScrollStitcher`（vDSP 行特征 + 全分辨率校验）12 帧 1500x800 拼接 55-63ms，合成帧拼接逐像素等于原图；`ScrollStitcherTests` 11 项、`ScrollCaptureControllerTests` 7 项全绿（本次全量 157 测试）
- 实现: ⌘⇧7 框选 → 自动滚动（CGEvent 投递到目标进程）→ 逐帧截图 → 拼接 → 进编辑器；Esc/结束按钮中止；最大 12 屏；失败给明确文案
- 决策记录: 滚动截图使用「框选区域」而非整窗，避开浏览器固定 UI 干扰；需要「辅助功能」权限，首次失败会弹系统授权提示
- Go/No-Go 依据（自动部分）: 拼接算法像素级正确、性能达标；滚动投递与真实页面效果待解锁后 live 验证
- Manual pending: 屏幕在 17:37 再次锁定，无法合成键鼠；解锁后跑 Chrome/Safari 长页面
