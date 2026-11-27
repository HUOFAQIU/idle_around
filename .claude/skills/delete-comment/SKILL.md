---
name: delete-comment
description: 清理首方 GDScript 注释，把决策迁入 docs/ 后用 no-comments lint 守住。
---

# 删除注释并迁移决策

规则以 `docs/指南/代码检查.md` 为准；这里只放执行步骤。

## 边界

- 只处理首方 6 个目录：`scripts/`、`main/`、`game/`、`godot_gas/`、`windows/`、`engine_tools/modkit/`。
- 不碰 `addons/`、`.godot/`、`base_mods/`、`mods/`。
- 保留四类注释，不迁移也不删除：
  - `@export` 及其变体（`@export_range` 等）正上方或行尾的 `##`（Godot Inspector 显示）。
  - `## @meta_addon` / `## @meta_author` / `## @meta_license` 来源标注。
  - 单行 `# why:` / `# invariant:` 契约标注（总长 ≤120 字符，就近标注关键顺序/边界不变量）。
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
| 局部不变量 | 单行就能说清的关键顺序、防坑原因（≤120 字） | 改写成 `# why:` 或 `# invariant:` 保留 |
| 长篇决策 | 跨文件流程、协议、多条边界与坑 | 先迁进 `docs/`，再删 |

## 2. 迁移决策

通过 `docs/INDEX.md` 路由表定位目标文档（跨模块口径与坑写入 `docs/架构/现状与注意.md` §2）。先 grep 目标文档确认未重复，只补文档里没有的内容，改完同步更新文档头「核对」日期。

## 3. 删除与验证

```bash
python -X utf8 -I tools/lint/strip_comments.py --write
python -X utf8 -I tools/lint/strip_comments.py --check
bash tools/check.sh --all
git diff --stat
```

`--check` 返回 0 表示首方已无待删注释；`no-comments` 单测在 `tools/lint/tests/test_rules.py`。

## 4. 汇报

报告：删除的文件数与注释数、保留的 `# why:`/`# invariant:` 数量、迁移进文档的决策清单（文档 + 小节）、`check.sh --all` 结果及未处理保留项。
