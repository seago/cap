# 35 · 项目文档双语（中文 / English）

Milestone: M5
Status: pending
Type: docs

## Goal

用户可见的项目文档提供英文版，与中文版互相链接：`README` / `DESIGN`。开发者内部文档（NOTES/GLOSSARY/ADR）保留中文为主，在文件头注明英文入口。

## Acceptance

- [ ] [auto] 英文文档中的命令可直接执行（构建/安装命令与中文版一致）
- [ ] [manual] README 顶部语言切换链接可用；DESIGN 同理
- [ ] [manual] 英文版覆盖功能、权限、快捷键、故障排查、里程碑状态

## Scope

In:

- `README.en.md`（全文英文）+ README 顶部 `[English]`
- `DESIGN.en.md`（全文英文）+ DESIGN 顶部 `[English]`
- GLOSSARY/ADR 文件头补一行英文摘要
