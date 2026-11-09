## Agent skills

### Issue tracker

Issues 和 specs 以 markdown 存放在 `.scratch/<feature-slug>/`。见 `docs/agents/issue-tracker.md`。

### Triage labels

Triage roles 使用五个默认 label 字符串：`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`。见 `docs/agents/triage-labels.md`。

### Domain docs

Single-context：根目录 `GLOSSARY.md` + `docs/adr/`。见 `docs/agents/domain.md`。

## 变更记录

每个逻辑步骤提交一次 commit，不按文件拆分；git 历史就是这一步的可审阅记录。

- 提交前运行 `git status` 与 `git diff`，确认只包含当前步骤的改动
- 运行相关构建或测试；未运行时在 commit body 写明原因
- 完成后在回复中给出 commit 短 hash

### Commit message

```text
<type>(<scope>): <一句话摘要>

功能点: <新增或变更的能力>
文件: A <path> / M <path> / D <path>（关键文件；完整清单见 git show --stat）
修复: <修复的问题，没有则省略>
验证: <执行的命令或检查清单>
Refs: <ticket 路径或 issue 编号，没有则省略>
```

`type` 取 `feat`、`fix`、`refactor`、`test`、`docs`、`chore`、`perf`。

## Workflows

- `workflows/cap-planning.md` — 队列空时拆 ticket，批准后写入 `.scratch/cap-v1/issues/`
- `workflows/cap-implementation.md` — 每个 ready ticket 一次 run，产出 commit + brief

## 项目文档

- `README.md` / `README.en.md` — 构建/安装/功能/快捷键/权限/项目结构/故障排查（中英）
- `DESIGN.md` / `DESIGN.en.md` — 设计稿、里程碑与 v1.1 实现状态（中英）
- `NOTES.md` — 环境事实与实现笔记（TCC、构建坑、技术决策）
- `GLOSSARY.md` — 领域术语（产品 + 工作流）
- `docs/adr/` — 架构决策记录
- `.scratch/cap-v1/` — tickets 与 milestones（实施记录）
