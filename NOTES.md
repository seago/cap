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

## Computer verification

- `screencapture` 可用；屏幕 1920x1200 @1x
- Accessibility **未授权**（`UI elements enabled = false`）：CGEvent 合成点击、System Events 按键不生效
- `cliclick` 未安装；`lsappinfo` 可用；Apple Event quit 可用
- 菜单栏 Cap 图标位置约 x=1436-1448、y=8-22（截图 diff 证据）
- Cap 自己的屏幕录制权限（TCC）只能由用户在系统设置里授予
- 若要让 agent 自动点击 / 输入，需要一次性给 DeepSeek Harness 开「辅助功能」权限
