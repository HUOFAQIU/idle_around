---
name: delete-comment
description: 清理首方 GDScript 注释：把决策记录迁进 DOC/，删除赘述/过时注释，最后用 no-comments lint 规则守住。适用于用户要求删除注释、整理注释、或重复本次注释清理流程时。
---

# 删除注释并迁移决策

规则以 `DOC/指南/代码检查.md` 为准；这里只放执行步骤。

## 边界

- 只处理首方 6 个目录：`Scripts/`、`Main/`、`game/`、`godot_gas/`、`Windows/`、`EngineTools/modkit/`。
- 不碰 `addons/`、`.godot/`、`base_mods/`、`mods/`。
- 保留三类注释，不迁移也不删除：
  - `@export` 及其变体（`@export_range` 等）正上方的 `##`：Godot Inspector 会显示。
  - `## @meta_addon` / `## @meta_author` / `## @meta_license`：来源标注。
  - `godot_gas/gameplay_tags.gd`：插件生成，改完会再生成。
- 不压空行。官方风格要求函数/类之间两个空行，压空行属于另一件事。

## 1. 盘点

```bash
python -X utf8 -I tools/lint/strip_comments.py --dry-run
```

工具按 `tools/lint/comment_policy.py` 判断哪些注释会被删。先看清数量和文件分布。

## 2. 分类

逐条（连续 `##` 块按整体）分成三类：

| 类别 | 判定 | 处理 |
|---|---|---|
| 赘述 | 只复述符号名、场景结构、显而易见的代码行为 | 直接删 |
| 过时 | 引用已删代码、旧命名、旧口径 | 直接删 |
| 决策记录 | 框架强约束、执行顺序原因、单位/边界/取整口径、引擎行为、已知坑 | 先迁文档，再删 |

拿不准时按决策记录处理，宁可多写一句文档。

## 3. 迁移决策

先 grep 目标文档，确认是否已经写过；只补文档里没有的，不重复搬运。

| 主题 | 文档 |
|---|---|
| 战斗施法/冷却/充能 | `DOC/架构/战斗运行时_施法与冷却.md` |
| 移动/刷怪/投射物 | `DOC/架构/战斗运行时_移动与投射物.md` |
| 伤害/异常/死亡 | `DOC/架构/战斗运行时_伤害与流程.md` |
| 技能/目标规则/魂灵数据 | `DOC/架构/战斗数据与魂灵.md`、`DOC/魂灵/` |
| GAS/属性/Cue | `DOC/架构/GAS.md`、`DOC/特效/effects.md` |
| 存档 | `DOC/架构/存档.md` |
| Mod | `DOC/架构/Mod系统.md`、`DOC/指南/Mod制作.md` |
| 背包/仓库/魂器 | `DOC/架构/背包_GBIS.md`、`DOC/魂灵/魂器.md` |
| 窗口/立方体 | `DOC/架构/窗口与场景.md`、`DOC/架构/立方体外壳.md` |
| 终端/命令 | `DOC/窗口/终端窗口.md`、`DOC/指南/命令控制台.md` |
| 地图 | `DOC/战斗/地图.md` |
| 颜色 | `DOC/架构/颜色与主题.md` |
| 调试/遥测 | `DOC/架构/调试与遥测.md` |
| 跨模块口径与坑 | `DOC/架构/现状与注意.md` §2 跨域坑 |

改文档时同步更新文档头的「核对」日期；新增文档才更新 `DOC/INDEX.md`。

## 4. 删除

迁移完成后：

```bash
python -X utf8 -I tools/lint/strip_comments.py --write
python -X utf8 -I tools/lint/strip_comments.py --check
```

`--check` 返回 0 表示首方已无待删注释。字符串里的 `#`（颜色值、`trace#%d`）由词法器排除，不会被误删。

## 5. 验证

```bash
bash tools/check.sh --all
```

同时确认：

```bash
git diff --stat
```

- `no-comments` 规则应替换掉旧的 `comment-marker`、`commented-code`，不要同时保留。
- 新规则的单测在 `tools/lint/tests/test_rules.py`。

## 6. 汇报

给用户报告：

- 删除的文件数、行数、行尾注释数，占总行数比例。
- 三类的数量。
- 迁移进文档的决策清单（文档 + 小节）。
- `check.sh --all` 结果。
- 未处理项：`addons/`、生成文件、Inspector 文档、来源标注。
