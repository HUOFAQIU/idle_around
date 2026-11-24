---
name: delete-comment
description: 清理首方 GDScript 注释，把决策迁入 DOC/ 后用 no-comments lint 守住。
---

# 删除注释并迁移决策

规则以 `DOC/指南/代码检查.md` 为准；这里只放执行步骤。

## 边界

- 只处理首方 6 个目录：`Scripts/`、`Main/`、`game/`、`godot_gas/`、`Windows/`、`EngineTools/modkit/`。
- 不碰 `addons/`、`.godot/`、`base_mods/`、`mods/`。
- 保留三类注释，不迁移也不删除：
  - `@export` 及其变体（`@export_range` 等）正上方的 `##`（Godot Inspector 显示）。
  - `## @meta_addon` / `## @meta_author` / `## @meta_license` 来源标注。
  - `godot_gas/gameplay_tags.gd`（插件生成，改完会再生成）。
- 不压空行。

## 1. 盘点与分类

```bash
python -X utf8 -I tools/lint/strip_comments.py --dry-run
```

按 `tools/lint/comment_policy.py` 逐条（连续 `##` 块按整体）分类：

| 类别 | 判定 | 处理 |
|---|---|---|
| 赘述 / 过时 | 只复述符号名、显而易见行为，或引用已删代码/旧命名 | 直接删 |
| 决策记录 | 框架强约束、执行顺序原因、单位/边界/取整口径、引擎行为、已知坑 | 先迁文档，再删 |

## 2. 迁移决策

通过 `DOC/INDEX.md` 路由表定位目标文档（跨模块口径与坑写入 `DOC/架构/现状与注意.md` §2）。先 grep 目标文档确认未重复，只补文档里没有的内容，改完同步更新文档头「核对」日期。

## 3. 删除与验证

```bash
python -X utf8 -I tools/lint/strip_comments.py --write
python -X utf8 -I tools/lint/strip_comments.py --check
bash tools/check.sh --all
git diff --stat
```

`--check` 返回 0 表示首方已无待删注释；`no-comments` 单测在 `tools/lint/tests/test_rules.py`。

## 4. 汇报

报告：删除的文件数与注释数、分类数量、迁移进文档的决策清单（文档 + 小节）、`check.sh --all` 结果及未处理保留项。
