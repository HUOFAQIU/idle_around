# 文档索引

> 唯一入口。用法：先在「需求 → 文档 / 代码」里找到目标，再只读目标文档的命中小节。
> 表中文档路径相对 `DOC/`；本页保持 ≤150 行，新增/删除文档时同步更新。

## 需求 → 文档 / 代码

| 你要做什么 | 先读 | 代码入口 |
|---|---|---|
| 了解项目结构、autoload、输入动作 | `架构/00_总览.md` | `project.godot` |
| 改启动链、单窗口外壳、面板清单/单例 | `架构/窗口与场景.md` | `Main/control.gd`、`Main/panel_manager.gd`、`Windows/base_window.gd` |
| 改面板拖动/关闭/标题栏、面板坐标 | `架构/窗口与场景.md` §1.2/§1.3 | `Windows/base_window.gd`、`Scripts/ui/control_drag.gd`、`Scripts/ui/ui_bounds.gd`、`Main/control.tscn` |
| 改面板置顶/激活/遮挡判断 | `架构/窗口与场景.md` §1.2/§3 | `Main/panel_manager.gd` |
| 改透明区域点击穿透/mouse_passthrough | `架构/窗口与场景.md` §1.7 | `Main/overlay_passthrough.gd`、`Scripts/ui/ui_region.gd` |
| 改主窗口置顶、T 按钮、置顶持久化 | `架构/窗口与场景.md` §1.6 | `Main/status_bar_container.gd`、`Scripts/window_pin_settings.gd` |
| 改主界面拖动/位置持久化 | `架构/窗口与场景.md` §1.5 | `Main/pet_panel.gd`、`Scripts/ui/control_drag.gd`、`Scripts/pet_panel_settings.gd`、`Scripts/settings_file.gd` |
| 主窗口置顶失效/置顶设置丢失 | `架构/窗口与场景.md` §3（常见排查） | `Main/status_bar_container.gd`、`Scripts/window_pin_settings.gd` |
| 改战斗单位、施法、冷却/扫描线 | `架构/战斗运行时_施法与冷却.md` | `game/battle/`、`Windows/Battle/` |
| 改移动、攻击范围门控、刷怪、空间索引、投射物 | `架构/战斗运行时_移动与投射物.md` | `game/battle/`、`Windows/Battle/` |
| 改暴击/伤害/异常、开战关窗、玩家怪物场景 | `架构/战斗运行时_伤害与流程.md` | `game/battle/`、`Windows/Battle/` |
| 改技能/目标规则/魂灵/怪物数据/掉落 | `架构/战斗数据与魂灵.md` | `base_mods/core/`、`game/content/` |
| 改背包/仓库/装备槽/拖拽 | `架构/背包_GBIS.md` | `Windows/Inventory/grid_base_inventory_system/`、`Scripts/warehouse.gd` |
| 改存档/读档/存档格式/迁移 | `架构/存档.md` | `Scripts/save/` |
| 读档丢物品/回退旧档/版本过高只读 | `架构/存档.md` §10（常见排查） | `Scripts/save/` |
| 改 GAS 属性/标签/Cue | `架构/GAS.md`、`特效/effects.md` | `godot_gas/`、`addons/GodotGAS/`、`Scripts/mod/mod_cue_registrar.gd` |
| 按完整链路理解系统 | `架构/关键流程.md` | `game/battle/`、`Windows/Inventory/` |
| 新增魂灵/怪物/魂器/技能/窗口/特效 | `架构/扩展点.md` | `base_mods/core/`、`game/content/`、`Main/control.gd` |
| 改 mod 加载/内容注册/存档兼容/管理窗口/加载顺序 | `架构/Mod系统.md` | `Scripts/mod/`、`Scripts/collection_db.gd`、`Scripts/save/`、`Windows/ModWindow/` |
| mod 未生效/内容缺失/orphaned/Cue 未注册/顺序不生效 | `架构/Mod系统.md` §11（常见排查） | `Scripts/mod/`、`Windows/ModWindow/` |
| 新增/修改官方魂灵、怪物、魂器、Cue | `架构/Mod系统.md`、`指南/Mod制作.md` | `base_mods/core/mod.json`、`modkit/validate_core_manifest.gd` |
| 查/改内容 ID、技能 ID、Cue 标签命名 | `指南/Mod制作.md` §3.1、`架构/Mod系统.md` §6 | `Scripts/mod/content_naming.gd`、`Scripts/mod/mod_loader.gd` |
| 制作/打包/发布 mod、看示例 | `指南/Mod制作.md` | `Scripts/mod/`、`mods/example_souls/`、`modkit/` |
| 确认功能是否已实现/已知坑 | `架构/现状与注意.md` | — |
| AI/自动化测试、构造战斗或背包场景 | `指南/AI测试接口.md` | `Scripts/test_api.gd` |
| 按症状排查战斗（不放技能/不触发/没伤害/Cue 不播/卡顿） | `指南/调试窗口.md` §常见排查、`架构/现状与注意.md` | `Windows/Debug/`、`game/battle/` |
| 新增调试事件或理解遥测数据 | `架构/调试与遥测.md` | `game/battle/battle_event.gd`、`game/battle/battle_event_bus.gd`、`Scripts/debug/`、`Windows/Debug/` |
| 改魂灵冷却/充能/冻结/主动效果 | `魂灵/主动魂灵.md` | `base_mods/core/souls/`、`game/content/`、`game/battle/charged_ability.gd` |
| 改被动魂灵/触发效果 | `魂灵/被动魂灵.md` | `base_mods/core/souls/`、`game/content/passive_soul_data.gd`、`game/content/passive_effect.gd`、`game/content/passive_trigger.gd` |
| 确认魂灵尺寸/魂器/角色魂器网格 | `魂灵/魂灵.md`、`魂灵/魂器.md` | `Windows/Inventory/grid_base_inventory_system/core/model/item/soul_data.gd`、`soul_vessel_data.gd`、`Windows/Vessel/`、`Windows/Character/` |
| 改怪物魂灵/掉落/刷新距离 | `怪物/怪物.md` | `base_mods/core/monsters/`、`game/content/monster_data.gd`、`game/content/monster_soul_entry.gd` |
| 改魂灵/魂器 tooltip 内容/格式 | `魂灵/魂灵.md`、`魂灵/魂器.md`、`架构/窗口与场景.md` | `Windows/Tooltip/` |
| 改颜色/色板（战斗状态/UI/场景/特效） | `架构/颜色与主题.md` | `Scripts/game_colors.gd` |
| 改见闻/图鉴/解锁（怪物/魂灵/魂器） | `窗口/见闻.md` | `Scripts/collection_db.gd`、`Windows/Collection/` |
| 改仓库窗口/背包理念/仓库分页 | `窗口/仓库.md` | `Windows/Inventory/`、`Scripts/warehouse.gd` |
| 改人物属性 | `属性/人物属性.md` | `godot_gas/attributes/player_stats_attribute_set.gd` |
| 查/改数值落地、取整口径 | `架构/现状与注意.md` §54、`架构/战斗运行时_伤害与流程.md` §1.1 | `game/battle/damage_resolver.gd`、`godot_gas/attributes/` |
| 确认战斗需求（设计） | `战斗/战斗逻辑.md` | `Windows/Battle/` |
| 补世界观 | `背景故事/背景故事.md` | — |
| 商业化脑洞（归档） | `archive/给AI玩的游戏.md` | — |
| 1/120 秒刻度约定/资源命名 | `魂灵/主动魂灵.md`、`架构/现状与注意.md` | — |

## 文档清单

| 文档 | 类型 | 状态 | 最后核对/整理 |
|---|---|---|---|
| `战斗/战斗逻辑.md` | 设计 | 有效 | 2026-11-14 |
| `属性/人物属性.md` | 设计 | 设计 | 2026-11-14 |
| `怪物/怪物.md` | 设计 | 部分实现 | 2026-11-14 |
| `窗口/仓库.md` | 设计 | 部分实现 | 2026-11-14 |
| `窗口/见闻.md` | 实现 | 已实现 | 2026-11-14 |
| `魂灵/魂灵.md` | 设计 | 部分实现 | 2026-11-14 |
| `魂灵/魂器.md` | 设计 | 已实现 | 2026-11-14 |
| `魂灵/主动魂灵.md` | 设计 | 部分实现 | 2026-11-14 |
| `魂灵/被动魂灵.md` | 设计 | 已实现 | 2026-11-10 |
| `archive/souls.xlsx` | 数据 | 归档（二进制，Claude 不可读） | — |
| `特效/effects.md` | 指南 | 有效 | 2026-11-14 |
| `指南/AI测试接口.md` | 指南 | 有效 | 2026-11-14 |
| `指南/调试窗口.md` | 指南 | 有效 | 2026-11-14 |
| `架构/调试与遥测.md` | 实现 | 有效 | 2026-11-14 |
| `背景故事/背景故事.md` | 设计 | 占位 | 2026-10-31 |
| `archive/给AI玩的游戏.md` | 记录 | 归档 | 2026-10-31 |
| `架构/00_总览.md` | 实现 | 有效 | 2026-11-14 |
| `架构/窗口与场景.md` | 实现 | 有效 | 2026-11-14 |
| `架构/战斗运行时_施法与冷却.md` | 实现 | 有效 | 2026-11-14 |
| `架构/战斗运行时_移动与投射物.md` | 实现 | 有效 | 2026-11-14 |
| `架构/战斗运行时_伤害与流程.md` | 实现 | 有效 | 2026-11-14 |
| `架构/战斗数据与魂灵.md` | 实现 | 有效 | 2026-11-14 |
| `架构/GAS.md` | 实现 | 有效 | 2026-11-14 |
| `架构/背包_GBIS.md` | 实现 | 有效 | 2026-11-14 |
| `架构/存档.md` | 实现 | 已实现 | 2026-11-14 |
| `架构/关键流程.md` | 实现 | 有效 | 2026-11-14 |
| `架构/扩展点.md` | 指南 | 有效 | 2026-11-14 |
| `架构/颜色与主题.md` | 实现 | 有效 | 2026-11-14 |
| `架构/现状与注意.md` | 实现 | 有效 | 2026-11-14 |
| `架构/Mod系统.md` | 设计 | 部分实现（内置 core mod 已接入） | 2026-11-14 |
| `指南/Mod制作.md` | 指南 | 部分实现（内置 core 已接入） | 2026-11-14 |

> `archive/souls.xlsx` 是旧计划表，文本工具读不了；要引用其中内容时先转成 Markdown 表格。
>
> `archive/` 下的内容只用于追溯，不参与当前实现；恢复使用时移回 `DOC/` 对应目录并更新本页。

## 文档头规范

每篇文档标题下紧跟一段引用块：

```markdown
> 类型：设计 / 实现 / 指南 / 记录 | 状态：设计 / 部分实现 / 已实现 / 有效 / 占位 / 废弃
> 何时读：一句话说明什么任务该打开它
> 关键词：同义词、类名、文件名，供 grep 命中
> 代码：相关入口文件；没有就写 —
> 相关：其他文档；可加「不覆盖」说明
> 核对：YYYY-MM-DD（实现类）或 整理：YYYY-MM-DD（设计类）
```

## 写作约定

1. 一篇文档一个主题；超过 200 行或包含 3 个以上主题就拆。
2. 只写代码里看不出来的：为什么、边界、数据流、扩展步骤、坑；不抄函数清单和资源枚举。
3. 内容清单以 `base_mods/core/mod.json` 为准；第三方 mod 以各自的 `mod.json` 为准。
4. 引用代码用符号（`file.gd::function`），不用行号。
5. 设计文档写「应该怎样」，架构文档写「现在怎样」；冲突时以代码为准并标注差异。
6. 过期内容移到 `DOC/archive/` 或删除，不留在正文。
7. 改代码时同步更新文档头的核对日期；新增/删除文档时更新本页。
8. 新增功能/内容时，同步在 `Scripts/test_api.gd` 暴露测试方法，并更新 `指南/AI测试接口.md`。

## 检索协议（配合 CLAUDE.md）

1. 先查本页路由表，不猜文件名。
2. 用关键词 grep 定位文件，先 `grep '^##'` 看标题，再按 `offset/limit` 只读命中节。
3. 不整篇读超过 200 行的文档；标记为「记录」的文档只在明确查历史时读。
4. 文档没覆盖时先 grep 代码符号，改完后把缺口补进对应文档。
5. 排障先查症状路由：症状 → 本页路由表 → 目标文档「常见排查」→ 再 grep 代码，不从头读实现文档。
6. 修复后把「症状 → 检查点 → 结论」回写对应文档的「常见排查」节；跨主题的坑写进 `架构/现状与注意.md`。
