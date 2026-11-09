
# Cap · 术语表

> 单上下文（single-context）领域文档：产品术语 + 工作流术语。术语变更请同步这里与 `NOTES.md`。

## 产品术语

| Term | 含义 |
|---|---|
| 截图（capture） | 一次从屏幕取图：区域 / 窗口 / 全屏三条路径 |
| 选区覆盖层 | 按 ⌘⇧2 后覆盖所有屏幕的交互层：压暗、十字准星、窗口高亮、尺寸标签 |
| 冻结面板 | 截图后覆盖在原选区上的编辑器窗口，下图定格、就地标注 |
| 标注版 / 原图 | Enter/⌘S 输出的渲染结果 vs 截取瞬间的原始位图；历史只保留最终版 |
| 滚动长截图 | ⌘⇧7 框选可滚动区域 → 自动滚动逐帧截图 → 拼接成长图；需辅助功能权限 |
| 拼接器（ScrollStitcher） | 纯算法：按行特征匹配相邻帧的重叠区，只追加新增行；歧义时宁停不出错位图 |
| OCR | Vision 本地文字识别；结果写回 `HistoryItem.ocrText` 并复制到剪贴板 |
| 贴图钉屏 / 钉屏 | 无边框浮窗显示一张截图；可拖动、滚轮缩放、双击复位、穿透点击；默认不进截图 |
| 历史（History） | `~/Library/Application Support/Cap/History/`：index.json + images/ + thumbs/，上限 100 条 |
| 标注工具组 | 矩形 / 箭头 / 直线 / 文字 / 画笔 / 高亮 / 马赛克 / 序号 / 裁剪 |
| 本地化（localization） | 界面文案的多语言版本；v1.1 支持 zh-Hans / en / zh-Hant，跟随系统语言 |
| String Catalog | `Localizable.xcstrings`：Xcode 的字符串目录，保存 key + 各语言翻译 |
| 开发语言（development language） | catalog 的源语言，本项目为 `zh-Hans`；缺失翻译时回退到源语言 |

## 工作流术语

| Term | 含义 |
|---|---|
| run | 一个连续工作块；通常只处理一个 ticket，产出一个 commit + brief |
| ticket | `.scratch/cap-v1/issues/NN-slug.md` 中的一个工作项，含 Status / Blocked by / Acceptance / Runs |
| ready ticket | `Status: ready-for-agent` 且 `Blocked by` 全部 `done` |
| auto / manual | 验收项能否由 agent 自动验证 |
| Deferred | 当前无法完成、明确记录后继续的验收项 |
| 验收（Accepted） | milestone 级结论：auto 全绿 + manual 项实测通过（或记录 Deferred） |
| brief | run/planning 结束时给用户的 decision-ready 摘要 |
| spike | 先用最小实验回答「能不能做 / 值不值得做」，产出 go/no-go 与限制 |

## 相关文档

- 设计：`DESIGN.md`
- 实施记录：`.scratch/cap-v1/`（milestones + tickets）
- 架构决策：`docs/adr/`
- 环境与实现坑：`NOTES.md`
- Agent 工作流：`AGENTS.md`、`workflows/`
