# 35 · 项目文档双语（中文 / English）

Milestone: M5
Status: done
Type: docs

## Goal

用户可见的项目文档提供英文版，与中文版互相链接：`README` / `DESIGN`。开发者内部文档（NOTES/GLOSSARY/ADR）保留中文为主，在文件头注明英文入口。

## Acceptance

- [x] [auto] 英文文档中的命令可直接执行（构建/安装命令与中文版一致）
- [x] [manual] README 顶部语言切换链接可用；DESIGN 同理
- [x] [manual] 英文版覆盖功能、权限、快捷键、故障排查、里程碑状态

## Scope

In:

- `README.en.md`（全文英文）+ README 顶部 `[English]`
- `DESIGN.en.md`（全文英文）+ DESIGN 顶部 `[English]`
- GLOSSARY/ADR 文件头补一行英文摘要

## Runs

### 2026-11-10 00:07 · run 1

- `README.en.md`：构建/签名/功能/快捷键/权限/数据位置/支持的 Mac/项目结构/故障排查 全文英文
- `DESIGN.en.md`：§0–§11 + 附录 A/B 全文英文（含 v1.1 状态、本地化、177 测试）
- `README.md` / `DESIGN.md` 顶部加 English 互链；GLOSSARY 增本地化术语；NOTES 增 xcstrings 工作流
- 验证：英文命令与中文版一致（xcodebuild/install.sh）；文档均以相对链接互指
