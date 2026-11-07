# 06 · 自签证书、安装与 TCC 持久性

Milestone: M0
Status: awaiting-manual
Blocked by: 04
Type: chore

## Goal

用本机自签证书签名 Release 版 Cap，安装到 `/Applications`，验证重建与重启后 TCC 不重复授权、⌘⇧2 仍可用。

## Acceptance

- [x] [auto] `security find-identity -v -p codesigning` 至少 1 个有效身份
- [x] [auto] `xcodebuild -configuration Release build` 通过；`codesign --verify --deep --strict` 通过；Bundle ID / 版本正确
- [x] [auto] 安装脚本把 `Cap.app` 复制到 `/Applications/Cap.app` 且可启动
- [x] [manual] 首次授权后退出；重建并替换 `/Applications/Cap.app`；再启动不重复弹权限
- [ ] [manual] 重启 macOS 后启动 Cap，⌘⇧2 仍能截图进剪贴板
- [x] [manual] 菜单栏图标、Dock 隐藏、退出菜单正常

## Scope

In:

- 生成 / 配置自签 codesigning 身份（脚本 + 说明；Keychain 交互时停下给命令）
- Xcode signing settings、Release 配置
- `Scripts/install.sh`（构建 + 复制到 `/Applications` + 启动）
- 签名与 TCC 验证记录

Out:

- 公证、App Store、自动更新
- 登录自启（M3）
- App 图标设计

## Files

- `Cap.xcodeproj/project.pbxproj`（signing 配置）
- `Scripts/install.sh`
- `Scripts/make-signing-identity.sh`（若采用脚本生成）
- `README.md`（安装 / 证书说明）

## Notes

- 本机当前 0 个 codesigning 身份；Keychain 可能要求用户确认
- 自签证书必须固定，否则 TCC 会把每次重建当新 App
- ad-hoc 签名不满足本 ticket 验收

## Runs

### 2026-11-08 03:10 · run 1

- Auto: 自签身份 `Cap Local Signing` ✅ / Release build + `codesign --verify` ✅ / 安装到 `/Applications/Cap.app` ✅
- Manual: TCC 跨重建 ✅（`touch` 源码 + 重新 install → 新 pid，`preflight=true`，`Cap_Toggle=1`）
- Manual pending: 重启 macOS 后 ⌘⇧2（重启会中断当前会话，留给 M0 验收）
- Manual: 菜单栏 / Dock / 退出 ✅（LSUIElement，沿用 #01 验证）
- Environment: 信任用 `security add-trusted-cert -r trustRoot`（用户域，无需 admin）
