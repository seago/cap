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
