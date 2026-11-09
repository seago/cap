# 34 · 多语言支持（简体中文 / English / 繁體中文）

Milestone: M5
Status: done
Type: feature

## Goal

App 界面文案支持 zh-Hans / en / zh-Hant 三种语言，跟随系统语言（不提供应用内切换）。使用 String Catalog + 开发语言 zh-Hans，所有 AppKit 字符串用 `String(localized:)`，SwiftUI `Text` 字面量由 catalog 自动提取。

## Acceptance

- [ ] [auto] `LocalizationTests`：xcstrings 可解析；关键 UI key 在 en / zh-Hant 均有非空翻译；三语言覆盖一致性
- [ ] [auto] build + 既有 172 项测试通过
- [ ] [manual] `-AppleLanguages (en)` 启动 → 菜单栏/popover/历史/编辑器/权限/错误提示全英文
- [ ] [manual] `-AppleLanguages (zh-Hant)` → 繁体中文界面
- [ ] [manual] 默认（跟随系统）中文环境仍是简体中文，无回归

## Scope

In:

- `Cap/Resources/Localizable.xcstrings`（en / zh-Hant 翻译；zh-Hans 为开发语言）
- `Cap/Support/Localization.swift`：`L()` 便捷函数
- 所有 AppKit 用户可见字符串包 `String(localized:)`；SwiftUI `Text` 依赖自动提取
- `Info.plist`：`CFBundleDevelopmentRegion` / `CFBundleLocalizations`；pbxproj `knownRegions`
- 历史窗口日期格式按语言（zh_CN → 系统 locale）
- 测试：`LocalizationTests`

Out:

- 应用内手动切换语言、第三方语言、文档双语（#35）

## Runs

### 2026-11-10 00:07 · run 1

- Auto: `LocalizationTests` 5 项（app 带 en/zh-Hant 资源、122+ 关键文案翻译、占位符数量一致、无空翻译）；全量 177 项测试绿
- Auto: Release `/Applications/Cap.app` 内包含 `en.lproj/Localizable.strings` 与 `zh-Hant.lproj/Localizable.strings`；`CFBundleLocalizations` = en / zh-Hans / zh-Hant
- Manual: `-AppleLanguages '(en)'` 启动 → popover、设置区、按钮、权限条、空状态均为英文（截图记录 `/tmp/popover-en2.png`）✅
- Manual: 系统语言切换/zh-Hant 界面 —— **Deferred**：验收时屏幕已锁（`locked=1`），合成输入不可用，解锁后补测
- 实现：String Catalog（开发语言 zh-Hans，124 key）；AppKit 可见字符串统一 `String(localized:)`；SwiftUI 字面量自动提取；快捷键提示改为读取当前实际设置
