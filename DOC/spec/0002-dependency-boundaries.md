# 0002 依赖边界 lint

> 状态：已实现 | 日期：2026-11-21 | 验收：`bash tools/check.sh --all`

## 问题

目录怎么分、谁能引用谁，只写在 `架构/边界与seam.md` 的判决表里。`game/` 引用 `Windows/`、`godot_gas/` 引用游戏代码，编译器和 lint 都不会说话；那份 P1 清单证明反向依赖已经发生过，靠人重读文档才发现。

## 方案

新增规则 `dependency-boundary`：把「层」定义为路径前缀，每层声明可读的目标前缀。同层永远放行；目标不属于任何层时默认放行（`Assets/`、`mods/`、`user://`）。

| 层 | 路径前缀 | 可读 |
|---|---|---|
| tools | `tools/`、`EngineTools/` | 全部 |
| main | `Main/` | 全部 |
| test-api | `Scripts/test_api.gd`、`Scripts/test_api/` | 全部 |
| windows | `Windows/` | `Scripts/`、`game/`、`godot_gas/`、`addons/`、`base_mods/`、`Assets/`、GBIS 核心、`Main/panel_manager.gd` |
| gbis | `Windows/Inventory/grid_base_inventory_system/` | `game/`、`addons/`、`Assets/`、`Scripts/game_colors.gd`、`Scripts/soul_text.gd`、`Scripts/mod/`、`Scripts/collection_db.gd` |
| script | `Scripts/` | GBIS 核心、`game/`、`godot_gas/`、`addons/`、`base_mods/`、`Assets/`、`Scripts/test_api.gd`、`Scripts/test_api/` |
| content-def | `game/content/` | `game/`、GBIS 核心、`godot_gas/`、`addons/`、`Assets/`、`Scripts/game_colors.gd`、`Scripts/debug/`、`Scripts/save/`、`Scripts/mod/`、`Scripts/collection_db.gd` |
| domain | `game/` | `game/content/`、GBIS 核心、`godot_gas/`、`addons/`、`Assets/`、`Scripts/game_colors.gd`、`Scripts/debug/`、`Scripts/save/`、`Scripts/collection_db.gd` |
| gas | `godot_gas/` | `addons/` |
| content | `base_mods/` | `game/`、`godot_gas/`、`addons/`、`Assets/`、GBIS 核心 |

层按最长前缀匹配，GBIS 核心与 `game/content/` 因此能从父层里独立出来。`game/content/` 与 `game/battle/` 实测互读（执行类在 content、定义被 battle 消费），表里按互读声明，收敛归 B3。边有三种来源：`res://` 字面量（`.gd`/`.tscn`/`.tres`）、`class_name` 标识符、autoload 单例名。类名到文件由扫描全仓 `class_name` 声明自建，不读 `.godot` 缓存；autoload 到文件写在表里，与 `project.godot` 的键集合不一致即报错。

## 用户可见行为

- 越界引用让 `--all` / `--staged` 失败，退出码 1。
- 报错含源文件:行、源层、目标层、目标路径。
- 文件不属于任何层、autoload 表与 `project.godot` 不同步，都直接报错。
- 存量违规进 `allowlist.toml`，写明原因与过期日期；过期、全量检查时未命中都让检查失败。

## 实施决策

- 表放 `tools/lint/boundaries.toml`，检查器放 `tools/lint/boundaries.py`：层表是策略、要能讨论，检查器是机械执行，分开。
- 不读 `.godot/global_script_class_cache.cfg`：它过期时规则会静默失效，0001 已踩过。
- 有意的反向依赖进表、不挂例外：`commands → test_api`（见 `指南/命令控制台.md`）、`content-def → ModLoader/CollectionDB`（内容定义的输入）都是架构事实，例外只留给该修的。
- 每个（文件，目标）只报一条并附次数，避免一个 UI 文件刷几十行。

## 测试决策

规则层用临时目录建最小工程做单测：路径越界、类名越界、autoload 越界各一条；同层放行、未配置目标放行、最长前缀生效各一条。验收跑 `--all`，引入后基线为 0 违规 + 5 条 allowlist（按文件×目标计）。

## 不在范围内

- GBIS 核心从 `Windows/` 迁出（B3）。
- `game/content/` 与 `game/battle/` 互读收敛（B3）。
- `domain → Scripts/debug/` 的遥测直连（端口化另开）。
- `base_mods/` 作为源扫描：v1 只作目标。

## 退出

层表与规则说明进 `指南/代码检查.md` 规则表和 `架构/边界与seam.md` 的判决；allowlist 清空后本文删除。
