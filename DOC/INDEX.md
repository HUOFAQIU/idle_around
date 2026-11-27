# 文档索引

> 唯一路由入口（5 个正交域：`架构/`、`设计/`、`指南/`、`spec/`、`adr/`）。先查下表找目标文档与代码入口，再按标题定位只读命中小节（规范与检索协议见 `指南/文档规范.md`）。

## 需求 → 文档 / 代码

| 你要做什么 | 先读 | 代码入口 |
|---|---|---|
| 项目总览、Autoload、输入动作、开发约定与引擎工具 | `架构/00_总览.md`、`指南/开发约定.md` | `project.godot`、`Scripts/GameGlobal.gd`、`EngineTools/` |
| 启动链、单窗口外壳、面板拖动/置顶/遮挡、Info/Item/Shop 窗口 | `架构/窗口与场景.md` | `Main/control.gd`、`Main/panel_manager.gd`、`Main/status_bar_container.gd`、`Windows/base_window.gd`、`Windows/Battle/battle_window.tscn`、`Windows/Info/`、`Windows/Item/`、`Windows/Shop/`、`Scripts/ui/`、`Scripts/window_pin_settings.gd` |
| 3D 立方体旋转/翻面、面片/PetPanel、透明点击穿透、拖动圆点 | `架构/立方体外壳.md` | `Main/Cube/`、`Main/pet_panel.gd`、`Main/Cube/Scripts/window_passthrough.gd` |
| 开局/新游戏/六槽存档选择/角色选择/面锁定 | `架构/开局流程.md`、`架构/存档.md` | `game/flow/game_flow.gd`、`game/content/Characters/`、`Main/Cube/Scenes/UI/` |
| 终端字符网格、ANSI、命令控制台与 Tab 补全 | `架构/终端窗口.md`、`指南/命令控制台.md` | `Scripts/terminal/`、`Windows/Terminal/`、`Scripts/commands/` |
| 见闻/图鉴解锁（怪物/魂灵/魂器） | `架构/见闻窗口.md` | `Scripts/collection_db.gd`、`Windows/Collection/` |
| 战斗施法、冷却/扫描线、1/120 秒刻度 | `架构/战斗运行时_施法与冷却.md` | `game/battle/`、`game/battle/soul_runtime_db.gd`、`Windows/Battle/` |
| 战斗移动、攻击范围门控、刷怪、空间索引、投射物 | `架构/战斗运行时_移动与投射物.md` | `game/battle/`、`Windows/Battle/` |
| 暴击/伤害/异常、数值取整口径、开战关窗与死亡 | `架构/战斗运行时_伤害与流程.md` | `game/battle/damage_resolver.gd`、`godot_gas/attributes/`、`Windows/Battle/` |
| 战斗数据、技能步骤、目标规则、掉落与魂灵运行时 | `架构/战斗数据与魂灵.md` | `base_mods/core/`、`game/content/` |
| 端到端关键链路串讲（战斗触发 / 拖拽与 Tooltip） | `架构/关键流程.md` | `game/battle/`、`Windows/Inventory/`、`Windows/Tooltip/` |
| 背包、仓库分页、装备槽、拖拽与容器 ID | `架构/背包_GBIS.md` | `game/inventory/grid_base_inventory_system/`、`Scripts/warehouse.gd`、`Scripts/container_ids.gd`、`Windows/Inventory/` |
| 存档格式、六槽读写、迁移与存档故障排查 | `架构/存档.md`、`指南/存档排查.md` | `Scripts/save/`、`game/flow/game_flow.gd`、`Scripts/test_api.gd` |
| GAS 属性集、标签注册与 Cue 特效接入 | `架构/GAS.md`、`指南/特效与Cue.md` | `godot_gas/`、`godot_gas/attributes/`、`addons/GodotGAS/`、`Scripts/mod/mod_cue_registrar.gd` |
| Mod 系统架构、加载顺序、内置 core 与 Mod 制作打包 | `架构/Mod系统.md`、`指南/Mod制作.md` | `Scripts/mod/`、`base_mods/core/mod.json`、`mods/example_souls/`、`EngineTools/modkit/`、`Windows/ModWindow/` |
| 扩展点（新增魂灵/怪物/魂器/技能/窗口/特效） | `指南/扩展点.md` | `base_mods/core/`、`game/content/`、`Main/control.gd` |
| 新增怪物与魂灵端到端制作流程（原型卡片→模型→魂灵→波次→验收） | `指南/内容制作流程.md` | `base_mods/core/mod.json`、`game/content/monster_data.gd`、`Windows/Battle/shaders/lit_unit.gdshader` |
| 魂灵规则（尺寸/标签/主动冷却/被动触发/Tooltip 格式） | `设计/魂灵.md` | `game/inventory/grid_base_inventory_system/core/model/item/soul_data.gd`、`game/content/passive_soul_data.gd`、`Windows/Tooltip/` |
| 魂器、角色魂器网格与情绪抽签系统 | `设计/魂器.md`、`设计/情绪系统.md` | `game/inventory/grid_base_inventory_system/core/model/item/soul_vessel_data.gd`、`game/content/soul_emotion*.gd`、`Windows/Vessel/`、`Windows/Character/`、`game/battle/loot_roller.gd` |
| 怪物设计、刷新距离、掉落与玩家/怪物属性池 | `设计/单位与属性.md` | `base_mods/core/monsters/`、`game/content/monster_data.gd`、`godot_gas/attributes/` |
| 地图物品、05 面地图板、刷怪配额、数量石与战斗设计 | `设计/地图与战斗.md` | `game/content/map_*.gd`、`Scripts/map_board.gd`、`Main/Cube/Scripts/map_board_content.gd`、`game/battle/map_run.gd` |
| 颜色规范与色板插件 | `架构/颜色与主题.md` | `Scripts/game_colors.gd`、`Scripts/game_color_catalog.gd`、`EngineTools/color_catalog/` |
| 调试窗口排障、遥测事件与启动耗时打点 | `指南/调试窗口.md`、`架构/调试与遥测.md` | `Windows/Debug/`、`Scripts/debug/`、`game/battle/battle_event_bus.gd` |
| AI 测试接口与命令控制台 | `指南/AI测试接口.md`、`指南/命令控制台.md` | `Scripts/test_api.gd`、`Scripts/test_api/`、`Scripts/commands/` |
| 提交前检查、Lint 规则、注释清理与情景回归测试 | `指南/代码检查.md` | `tools/check.sh`、`tools/lint/`、`tools/compile_check/`、`tools/scenarios/`、`tools/git-hooks/` |
| 模块边界、依赖层表与临时例外清单 | `架构/边界与seam.md` | `tools/lint/boundaries.toml`、`tools/lint/allowlist.toml` |
| 变更契约（Spec）、架构决策（ADR）与需求拷问 | `spec/README.md`、`adr/README.md` | `.claude/skills/grill/` |
| 文档写作约定、文档头规范与低 Token 检索协议 | `指南/文档规范.md` | `tools/lint/index_meta.py`、`CLAUDE.md`、`.claude/`、`tools/claude_hook.py` |
| 功能实现现状、跨域已知坑与术语表 | `架构/现状与注意.md`、`术语表.md` | — |
