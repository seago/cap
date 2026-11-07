# Milestone 验收

> 从 `DESIGN.md` §7 每个 milestone 的「验收」段落生成。
> 逐项勾选；全部勾选后写 `Accepted: YYYY-MM-DD`。
> 环境限制无法完成的项记为 `Deferred:` 并写明原因与补验方式。

## M0 · 骨架与全屏截图

- [x] 全新安装 → 引导授权
- [x] 关掉 Xcode 后 ⌘⇧2 仍能截图进剪贴板
- [x] 重建后权限不需要重新授予
  - 证据：自签身份 `Cap Local Signing`；重装 `/Applications/Cap.app` 后 `Screen recording permission: true`
- [ ] 重启系统后 ⌘⇧2 仍能截图进剪贴板
  - Deferred: 重启会中断当前会话与其他工作，不擅自重启用户机器
  - 补验：下次重启后启动 Cap，按 ⌘⇧2，确认 `Captured display` 日志与剪贴板 PNG

Accepted: 2026-11-08（deferred: 重启系统后 ⌘⇧2；不擅自重启用户机器，下次重启后补验）

### M0 支撑证据

- #01 菜单栏 App、`LSUIElement`、退出
- #02 ⌘⇧2 全局热键（20 次合成触发 20/20）
- #03 首次启动引导、深链、TCC 授权
- #04 全屏截图 → 剪贴板 PNG + TIFF，无光标、无 Cap 窗口
- #05 历史 `index.json` + `images/{uuid}.png`，重启读回
- #06 自签签名、安装到 `/Applications`、重建后 TCC 保持
- #07 「重新启动 Cap」真实拉起新实例

## M1 · 选区层

- [x] 多屏覆盖层、压暗、十字准星、窗口高亮、尺寸标签（单屏验证）
- [x] 拖动 / 单击 / 空格 / Enter / Esc；3pt 阈值
- [x] 区域截取（15.2 跨屏 API）
- [x] 窗口截取（含阴影；Option 不带）
- [x] 全屏（鼠标所在屏）
- [x] 截取即进剪贴板 + 历史
- [x] 排除自身窗口（三种截图类型均无覆盖层）
- [x] 20 次连续截取稳定（20/20，0 失败）
- [ ] 双屏环境连续 20 次区域 / 窗口截取，输出不含 Cap 自己的 UI
  - Deferred: 本机只有一块显示器（1920x1080）
- [ ] 跨屏选区尺寸正确
  - Deferred: 同上
- [ ] 撤销/恢复屏幕录制权限的 live 验证
  - Deferred: 需要管理员授权，可能中断会话

Accepted: 未验收（deferred: 多屏两项、TCC 撤销两项）
