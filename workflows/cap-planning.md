# Cap Planning Loop

> 队列空时，把 `DESIGN.md` 的下一个 milestone 拆成 3–7 个可执行 ticket；批准后写入 `.scratch/cap-v1/issues/`。

## Trigger

- 执行 loop 发现没有 ready ticket（队列空，或只剩 blocked）
- 用户明确说「拆 ticket / 规划下一批」
- 用户说「只拆不跑」

## Gates

按顺序检查，任一不过就停并报告。

### 0. 队列已有 ready ticket

- 若存在 `Status: ready-for-agent` 且未被 block 的 ticket → 提示先执行现有 ticket，停。
- 例外：用户明确说「继续拆 / 只拆不跑」时，跳过本 gate。

### 1. §11 默认值

- 检查 `DESIGN.md` §11 是否已标记「已确认」。
- 未确认 → 输出 5 项（当前推荐值）并停，等用户逐项确认；确认后在 §11 标题下写入 `状态：已确认（YYYY-MM-DD）`，提交 `docs(design): confirm §11 defaults` 并 push。
- 已确认 → 继续。

### 2. 当前 milestone 验收

- 当前 milestone = `DESIGN.md` §7 中第一个未通过验收的 milestone（M0 起步）。
- 若该 milestone 还没有任何 ticket：尚未开始，跳过验收检查，进入规划。
- 若该 milestone 已有 ticket，且还有 ticket 不是 `done`（`awaiting-manual` 也算未完成）：
  - 输出未完成 ticket 列表 + 各自 manual 待验收项
  - 停，等用户验收或决定
- 若全部 `done`，检查 `.scratch/cap-v1/milestones.md` 中该 milestone 的验收清单：
  - 全部勾选 → 写 `Accepted: YYYY-MM-DD`，进入下一个 milestone
  - 未全部勾选 → 输出清单并停，等用户逐项确认
- `.scratch/cap-v1/milestones.md` 不存在 → 从 `DESIGN.md` §7 的「验收」段落创建，提交 `docs(milestone): add M0 checklist` 并 push

### 3. 阻塞项

- 队列中有 `Status: blocked` ticket 时：
  - 列出编号、卡点、已试方案
  - 给出建议：改 ticket / 拆小 / 跳过 / 放弃
  - 停，等用户决定；不自动生成新 ticket

### 4. 队列为空

- 正常进入规划。

## Inputs

- `DESIGN.md`：§1 范围、§3 交互、§4 技术、§5 架构、§7 里程碑、§8 测试计划、§11 默认值
- 现有 tickets 与 `## Runs`（避免重复）
- `.scratch/cap-v1/milestones.md`（存在则读）
- `AGENTS.md` 与 `docs/agents/*`

## Steps

1. 确定 milestone：第一个未通过验收的。
2. 从 §7 该 milestone 的条目拆 3–7 个 tracer-bullet tickets：
   - 一个 ticket 能在一次 run（约 1–3 小时）内完成
   - 一个 ticket 能独立 commit、独立回滚
   - 按依赖顺序编号，接续现有最大编号
3. 为每个 ticket 写全模板字段，验收项逐条标 `[auto]` / `[manual]`。
4. 输出 ticket 列表 brief：
   - 编号、标题、Type、Blocked by
   - 验收项数量（auto / manual）
   - 一句话说明为什么这样拆
5. 等用户批准；用户可增删改。
6. 批准后写入 `.scratch/cap-v1/issues/NN-slug.md`，提交 `docs(tickets): add <milestone> batch #NN-#MM` 并 push。
7. 用户要「只拆不跑」→ 结束；否则转入 `workflows/cap-implementation.md`，执行第一个 ready ticket。

## Ticket 模板

```markdown
# NN · <标题>

Milestone: M0
Status: ready-for-agent
Blocked by:
Type: feature | fix | refactor | test | chore

## Goal

一句话说明这个 ticket 完成后用户能做什么。

## Acceptance

- [ ] [auto] `xcodebuild ...` 通过
- [ ] [auto] `GeometryTests` 新增用例通过
- [ ] [manual] 双屏跨屏拖选，输出尺寸正确

## Scope

In:
- ...

Out:
- ...

## Files

- `Cap/...`
- `CapTests/...`

## Notes

- 引用 `DESIGN.md` 的章节
```

- `Blocked by:` 为空或写编号；只能依赖更早的编号，保证无环。
- 一个 ticket 只对应一个功能点或一个修复。

## Ticket 列表 Brief

```text
Milestone: M0 · 骨架与全屏截图
将入队 5 个 ticket:

#12 M0-1 创建 Xcode 工程与菜单栏骨架
    auto 3 / manual 1 · 无依赖
#13 M0-2 权限引导与 preflight
    auto 2 / manual 2 · Blocked by #12
...

批准后写入 .scratch/cap-v1/issues/，并从 #12 开始执行。
```

## Milestone 验收记录

文件 `.scratch/cap-v1/milestones.md`：

```markdown
# Milestone 验收

## M0 · 骨架与全屏截图

- [ ] 全新安装 → 引导授权
- [ ] 关掉 Xcode 后 ⌘⇧2 仍可用
- [ ] 重启系统后 ⌘⇧2 仍可用
- [ ] 重建后 TCC 不需要重新授权

Accepted: 未验收
```

- 初始内容从 `DESIGN.md` §7 的「验收」段落生成
- 用户逐项确认后勾选；全部勾选后写 `Accepted: YYYY-MM-DD`
- 修改后提交 `docs(milestone): accept M0` 并 push
- planning 只认这个文件的勾选与 `Accepted` 状态

## 编号规则

- 全局递增，接续 `.scratch/cap-v1/issues/` 现有最大编号；目录不存在则从 `01` 开始
- 编号顺序 = 建议执行顺序（blocking 优先）
- 编号一旦写入不复用、不重排

## Done

- 通过全部 gates
- 批准后的 ticket 已写入
- 用户已明确下一步：继续执行，或只拆不跑
