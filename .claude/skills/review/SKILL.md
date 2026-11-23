---
name: review
description: 审查一次改动：Standards 轴查项目规则（lint、注释、TestAPI 与文档同步、依赖边界），Spec 轴查实现是否符合 DOC/spec 的行为清单。用户说 review、「审一下」「检查这次改动」「能不能提交」时使用。
---

# 双轴审查

只报本次改动引入或加重的问题；范围外的旧账单独列，不混进结论。

## 0. 定范围

- 默认：`git status` + `git diff`，含未跟踪文件。
- 用户给了 PR、分支、路径或 commit 时以它为准。
- 先读改动涉及的 spec 和目标文档，再读代码。spec 已删除时用 `git show HEAD:DOC/spec/NNNN-x.md` 读取。

## 1. Standards 轴（总是跑）

规则来源：`.claude/rules/`、`DOC/INDEX.md` 写作约定、`DOC/指南/代码检查.md` 规则表。

```bash
bash tools/check.sh --all
```

必须绿；红了先修，不要把红当发现往上报。

人工项：

- 首方 GDScript 无注释，例外仅 `@export` 正上方的 Inspector 文档、`@meta` 标注、生成文件。
- 新增功能或内容同步暴露 TestAPI：域模块实现 + `Scripts/test_api.gd` 门面转发；只有新增域或入口语义变化才改 `DOC/指南/AI测试接口.md`。
- 改功能时旧代码、旧命名、旧迁移、旧文档描述一并删除，没写兼容层。
- 依赖边界：层次表以 `tools/lint/boundaries.toml` 为准，重点看 `Windows/` 不读 `Scripts/test_api`、`game/content/` 与 `game/` 单向。
- `addons/` 未被改动；确需改动时事先说明。
- 文档头「核对」日期与本次改动一致；改文档内容后先更新文档头日期，再跑 `index_meta.py --write` 同步 `DOC/INDEX.md` 对应行；新增或删除文档才增删清单行。
- 存档和设置格式可以破坏，但无头探针不能写真实 `user://`。

## 2. Spec 轴（有 spec 才跑）

在 `DOC/spec/` 找状态为「已约定」或「已实现」、且覆盖本次改动的 spec：

- 逐条对照「用户可见行为」；缺一条是发现，多出没写的可见行为也是发现。
- 跑 spec 头写的验收命令，确认是绿的。
- 核对「不在范围内」确实没做。
- 审查时 spec 必须仍在、状态为「已实现」；review 通过后才执行「退出」：抄进 `架构/` 或 `指南/`、转 ADR，或删除。

没有对应 spec 就跳过这一轴，不临时补造。如果这次改动其实触发了 `DOC/spec/README.md` 的触发表，报「缺 spec」，不要替它写。

## 3. Bug 轴

通用缺陷和逻辑错误交给全局 `/code-review`（它会读 CLAUDE.md）。先跑它，本 skill 不重复它的结论，只补它看不到的项目特有项，即上面两轴。

## 4. 输出

按 `file:line` 分组，每条三段：问题 / 依据（引哪条规则或 spec 哪一行）/ 建议。拿不准的标「待确认」，说明还差什么证据。

最后一行给结论：`可提交` 或 `需修 N 项`。修完复跑 `bash tools/check.sh --all`。结论为「可提交」后，才退出并删除 spec，再 commit，最后写交接。
