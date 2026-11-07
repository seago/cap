# Cap 实施 Loop

> 一个 run = 一个 ready ticket = 一个绿色 commit + 一份 brief。
> 执行侧 source of truth；拆 ticket 见 `workflows/cap-planning.md`。

## Trigger

用户说「继续 Cap / 跑下一个」，或 planning 批准一批 ticket 后自动继续。

1. 扫描 `.scratch/cap-v1/issues/*.md`，找 `Status: ready-for-agent` 且未被 block 的 ticket：
   - `Blocked by:` 为空，或列出的每个编号对应 ticket 的 `Status: done`
2. 有 → 取编号最小的一个；用户点名某个 ticket 时取点名的。进入本 workflow。
3. 没有 → 转入 `workflows/cap-planning.md`；planning 批准后回到本 workflow 执行第一个 ticket。

例外：用户说「只拆不跑」时只执行 planning，不进入本 workflow。

## Preconditions

任一不满足就停止并报告，不开始实现：

- `git status --porcelain` 为空
- `git pull --ff-only origin main` 成功
- ticket 仍存在且 `Status: ready-for-agent`
- `DESIGN.md` 与 ticket 引用的文档可读
- `xcodebuild -version` 可用

## Inputs

按顺序读取，不要通读无关章节：

1. `AGENTS.md`
2. 目标 ticket 全文
3. `docs/agents/issue-tracker.md`、`docs/agents/triage-labels.md`、`docs/agents/domain.md`
4. `DESIGN.md`：ticket 对应 milestone 的 §7，以及 ticket 引用的 §3 / §4 / §5
5. `GLOSSARY.md`、`docs/adr/`（存在则读）
6. ticket 的 `## Runs`（重跑时）

## Steps

1. **Claim** — 把 ticket 的 `Status:` 改为 `in-progress` 并保存。
2. **Plan** — 用 3–6 行写出实现顺序、要改的文件、验证命令。ticket 缺验收项或范围矛盾时，按「卡住」处理。
3. **Implement** — 只改 ticket `In` 范围内文件。
4. **Build** —

   ```bash
   xcodebuild -project Cap.xcodeproj -scheme Cap -configuration Debug build
   ```

   M0 首个 ticket 负责创建工程并验证该命令；scheme 或命令不同时，以该 ticket 的 `## Runs` 记录为准。
5. **Test** —

   ```bash
   xcodebuild test -project Cap.xcodeproj -scheme Cap -destination 'platform=macOS'
   ```

   尚无测试 target 时记为 `N/A`，在 brief 说明。
6. **Auto acceptance** — 逐条执行 `[auto]` 验收项，全部通过才可 commit。
7. **Manual acceptance** — 原样收集 `[manual]` 项，本 run 不执行、不声称通过。
8. **Update ticket** — 在 commit 之前完成，保证工作区干净：
    - 有 manual 项 → `Status: awaiting-manual`
    - 无 manual 项 → `Status: done`
    - 追加 `## Runs` 记录（不写 commit hash；hash 见 brief）
9. **Commit** — 一个 run 一个 commit，包含代码与 ticket 更新；格式见 `AGENTS.md` 的「变更记录」；`Refs` 指向 ticket 路径。
10. **Push** — `git push origin main`。失败不阻塞，记录「未推送」，下次 run 补推。
11. **Brief** — 按固定格式输出，结束本次 run。

## 验证规则

- `[auto]` 必须由 agent 在本机实际执行，结果记录为「命令 + 通过数」。
- `[manual]` 由 agent 先用 computer use 验证：截图、`CGWindowList`、`lsappinfo`、Apple Event、Accessibility API 等。取得可核对证据后在 Acceptance 勾选，证据写进 `## Runs`。
- 只有两种情况留给用户：权限阻止操作（Accessibility / TCC），或需要主观判断（视觉设计、手感）。留给用户的项必须写明原因。
- 当前环境：屏幕截图可用；Accessibility 未授权，合成点击 / 按键会被系统忽略；TCC 授权面板不能由 agent 自行勾选。
- 不伪造验证结果。agent 无法验证的项一律写「待用户验收」。
- auto 失败 → 修复后重跑；同一阻塞点 3 次无进展 → 停止。
- 环境问题（Xcode、SSH、TCC 弹窗）不计入 3 次，直接停止并报告。

## Computer verification

可用：

- `screencapture -x -R x,y,w,h` + 读图：菜单栏、窗口、对话框
- `lsappinfo`：进程类型（UIElement / Foreground）、bundle id、pid
- `CGWindowListCopyWindowInfo`：窗口 / 状态栏 item 的 layer 与 bounds
- Apple Event：`osascript -e 'tell application id "..." to quit'` 验证退出路径
- `plutil` / `defaults read`：Info.plist 与偏好
- 单测 + 脚本断言：逻辑与数据

受限：

- Accessibility 关闭时，`CGEvent` 合成点击、`System Events` keystroke 不生效；需要在「系统设置 → 隐私与安全性 → 辅助功能」为 DeepSeek Harness 授权一次。
- Cap 自己的屏幕录制权限只能由用户在系统设置里授予；agent 可以打开面板并截图确认状态，但不能替用户点「允许」。
- 视觉判断（图标好看、手感）仍以用户为准。

## 卡住 / 失败

任一情况停止，**不提交代码**（记录变更仍要单独提交，见下）：

- 同一阻塞点尝试 3 次仍无进展（至少换过一种方案）
- ticket 验收项自相矛盾或缺少必要信息
- 构建环境不可用
- `[auto]` 项无法执行且无法改造成可执行

动作：

1. ticket `Status:` 改为 `blocked`；`## Runs` 追加失败记录（尝试过什么、卡点在哪），并记 `Stash: blocked #NN <date>`（有代码改动）或 `Stash: 无残留代码`（无改动）
2. 只提交 `.scratch/` 下的记录变更（blocked 状态、Runs、本次按范围纪律新开的 ticket）：`git add .scratch/cap-v1 && git commit -m "docs(ticket): block #NN"` 并 push；**不提交代码**
3. 若仍有代码改动，执行 `git stash push -u -m "blocked #NN <date>"`，确认工作区干净
4. brief 说明卡点与建议（改 ticket / 拆小 / 需要用户决策）

环境问题（Xcode/SSH/权限弹窗）没有代码改动时，跳过 stash，直接走第 2 步。

## 中断

用户主动中断（取消 / 关闭会话）时，按失败流程收尾：

- 无代码改动 → ticket 恢复 `ready-for-agent`，不产生 commit
- 有代码改动 → ticket 改为 `blocked`，按上面步骤提交记录并 stash

若会话被直接关闭、来不及收尾，下一次 run 的 preflight 会因工作区不干净而停下，由用户决定恢复或丢弃。

## 范围纪律

- 本次只实现 ticket 的 `In` 范围，不顺手修范围外问题。
- 发现范围外问题 → 新建 ticket：`Status: ready-for-agent`，`Refs: 发现于 #NN`，追加到队列末尾编号；单独提交 `docs(tickets): open #NN <slug>` 并 push，不放进本次 run 的 commit。
- 新 ticket 写入 brief 的「偏差」；若该问题**阻碍**原 ticket 完成，按「卡住」处理，不扩大范围。

## Commit

格式与字段遵循 `AGENTS.md`：

```text
<type>(<scope>): <一句话摘要>

功能点: <新增或变更的能力>
文件: A <path> / M <path> / D <path>
修复: <修复的问题，没有则省略>
验证: <命令与结果>
Refs: .scratch/cap-v1/issues/NN-slug.md
```

- 包含代码 + ticket 的状态与 `## Runs` 更新
- 只包含本 ticket 的改动
- 成功 run 一个 commit；失败 run 不产生代码 commit，只有 `docs(ticket): block #NN` 记录 commit
- 不 amend、不 force push、不 rebase 已推送历史
- 一个 run 一个 commit

## Push

- 每个 commit 后执行 `git push origin main`（run、planning、manual 验收、milestone 验收的提交都适用）
- 失败：brief 记「未推送」；下次交互先补推，再继续
- 任何情况下不 force push

## Ticket 状态

```text
ready-for-agent → in-progress → done
                              ↘ awaiting-manual → done（用户验收后）
                              ↘ blocked
```

- agent 能验证的 `[manual]` 项：勾选并在 `## Runs` 记录证据；全部通过 → `done`
- agent 无法验证的项：保留未勾选，`Status: awaiting-manual`，brief 写明原因
- `awaiting-manual` 不阻塞 commit，但会阻止 milestone 验收与 planning 继续
- 用户确认通过：把 ticket 改为 `done`，`## Runs` 追加「manual 通过」；单独提交 `docs(ticket): mark #NN manual accepted` 并 push。该提交是验收记录，不是一次 run。
- 用户报告 manual 失败：原 ticket 改为 `blocked`，新建 fix ticket；同样单独提交并 push。
- 所有 docs 提交同样按 `AGENTS.md` 的 commit 模板写 body（`验证` 字段写用户确认结果）。

## `## Runs` 格式

每次 run 追加，不覆盖：

```markdown
### 2026-11-08 02:30 · run 1
- Auto: build ✅ / 12 tests ✅ / 3 assertions ✅
- Manual pending: 双屏跨屏拖选；覆盖层未被截入
- Risk: 混合 DPI 下 1px 边界可能差 1pt → #07
```

Runs 在 commit 前写入，因此不含本次 commit hash；hash 见 brief，或用 `git log --grep 'Refs: .scratch/cap-v1/issues/NN'` 查。

## Brief

```text
Ticket: #03 跨屏选区
功能点: 拖动选区支持跨屏，1px 精度
验证: build ✅ / unit 12 passed ✅ / auto 断言 ✅
Commit: 1a2b3c4 (pushed)
待你验收: [manual] 双屏跨屏拖选；[manual] 覆盖层未被截入
风险/偏差: 混合 DPI 1px 边界 → #07
下一步: #04 编辑器冻结面板
```

- 只写 decision-ready 信息；不贴 diff、不贴完整日志
- 必须包含：ticket、功能点、auto 结果、commit/push、manual 状态（已验证 + 证据 / 待你验收 + 原因）、风险/偏差
- 结尾给「下一步」：下一个 ready ticket 编号，或「队列空，已转入 planning」

## Done

- ticket 已实现
- build + 单测 + 所有 `[auto]` 通过
- 所有可验证的 `[manual]` 已勾选并记录证据；否则 ticket 为 `awaiting-manual`
- 一个 commit 已创建；push 成功，或已记录待推
- ticket 状态与 `## Runs` 已更新
- brief 已输出

## 不做

- 一次 run 处理多个 ticket
- 把无法验证的 manual 项写成通过
- 在未授权 Accessibility / TCC 时假装完成了点击或授权
- 顺手修范围外问题
- 改写已提交历史
- 绕过 planning 直接拆新 milestone
