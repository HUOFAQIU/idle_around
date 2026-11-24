# Mod 制作与打包

> 类型：指南 | 状态：部分实现（内置 core 已接入） | 核对：2026-11-24
> 何时读：制作、打包、发布第三方 mod，查阅 ID/标签命名规则或新增官方内置 core 内容
> 关键词：mod.json content.pck modkit pack_example patch 命名规则 PascalCase core validate_core_manifest
> 代码：`Scripts/mod/`、`base_mods/core/mod.json`、`mods/example_souls/`、`EngineTools/modkit/`
> 相关：`架构/Mod系统.md`、`指南/AI测试接口.md`、`指南/开发约定.md`
> 不覆盖：ModLoader 启动时序、安全边界与常见排查（见 `架构/Mod系统.md`）、完整 TestAPI 列表（见 `指南/AI测试接口.md`）

## 1. 目录与 `mod.json` 规格

第三方 mod 放 `user://mods/<mod_id>/`，发布目录仅需 `mod.json` + `content.pck`（`mod.json` 必须在 PCK 外面；开发期可省略 PCK 用 loose 模式调数据，但贴图/场景不走导入流程）。

| 字段 | 必填 | 说明 |
|---|---|---|
| `schema` / `id` | 否 / 是 | `schema` 默认 `1`；`id` 全局唯一小写 `snake_case`（`^[a-z][a-z0-9_]{2,63}$`） |
| `name` / `version` / `author` / `description` | 否 | Mod 窗口展示字段 |
| `game_version` | 否 | `{ "min": "0.1.0", "max": "0.2.0" }`（包含边界，缺省段按 0 补齐） |
| `dependencies` / `load_after` | 否 | 硬依赖（缺失/禁用则不加载） / 软顺序（目标不存在则忽略） |
| `content_namespace` / `content_root` | 否 | **仅限内置 mod**（`"global"` 与自定义根）；第三方填写会被拒绝 |
| `content.{souls,monsters,vessels,cues}` | 否 | `id`+`path`（Cue 为 `tag`+`scene`），路径须落在本 mod 命名空间目录下 |
| `overrides` | 否 | 声明覆盖的原版 `res://` 路径（必须存在，禁盖 `project.godot`/`.godot/`/`base_mods/*/mod.json`/`Scripts/mod/`） |

## 2. 命名规则（唯一权威表）

资源 ID 统一小写 `snake_case`（`:` 分隔命名空间）；GAS 标签每段 `PascalCase` 无下划线（`.` 分隔层级）。魂灵/怪物 ID 是**存档键**，发布后不可改名。

| 类型 | 规则 | 示例 |
|---|---|---|
| core 魂灵 / 怪物 / 魂器 ID | `<name>_{soul\|monster\|vessel}` | `kong_lang_soul` |
| 第三方魂灵 / 怪物 / 魂器 ID | `<mod_id>:<name>_{soul\|monster\|vessel}` | `example_souls:fire_wolf_soul` |
| core 技能 ID | 魂灵 ID 去 `_soul` 转 PascalCase | `<PascalName>` → `Skill.<PascalName>` |
| 第三方技能 ID | `Mod.<PascalModId>.<PascalName>` | `Mod.ExampleSouls.FireWolf` |
| core / 第三方 Cue 标签 | `Cue.<Category>.<Name>` / `Cue.Mod.<PascalModId>.<Name>` | `Cue.Status.Burn` / `Cue.Mod.ExampleSouls.Fire` |

- `SkillDefinition.id` 留空时 `ModLoader` 按 `content_id` 自动派生；core 技能 ID 由 `CoreContentValidator` 强制对齐。
- Cue 根节点须继承 `GameplayCueNotify`；Cue 标签不要求写入游戏 `tag_registry.tres`，运行时按字符串匹配。

## 3. Godot 4.7 打包与 Patch 导出

- **一键打包示例 mod**（`mods/example_souls/`，`GODOT_BIN` 见 `指南/开发约定.md`）：
  ```bash
  "$GODOT_BIN" --headless --path . --script res://EngineTools/modkit/pack_example.gd
  ```
  生成 `user://mods/example_souls/{content.pck,mod.json}`（`--script` 跳过读档不碰存档；打包前请关游戏避免占用 PCK）。建新 mod 复制 `mods/example_souls/` 并同步 `id`/内容 ID/技能 ID/Cue 前缀与打包脚本 `MOD_ID`。
- **Patch 导出**：保持相同 Godot 4.7.x 版本，在导出预设 Patching → Base Packs 选游戏基础 `.pck` 导出普通 patch PCK（主工程 `export_presets.cfg` 须保持 `binary_format/embed_pck=false`，勿开 delta 编码与加密）。

## 4. 官方内置内容（`base_mods/core/`）与校验

- 官方清单在 `base_mods/core/mod.json`（loose 模式，按 `souls/`、`monsters/`、`vessels/`、`effects/`、`cues/` 存放，技能/触发器/effects 由资源内部引用不单独登记）；ID 不加 `core:` 前缀。
- 主包导出过滤：`include_filter` 必须含 `base_mods/*/mod.json`；`exclude_filter` 用 `mods/*,EngineTools/*`（勿写 `*mods/*`）。
- **改完必跑校验**：`"$GODOT_BIN" --headless --path . --script res://EngineTools/modkit/validate_core_manifest.gd`（或 `TestAPI.validate_core_manifest()`），以纯文本扫描 `.tres` 校验漏登、断链、技能 ID 派生与中文 `resource_name`。
- **落地数值必须写整数**：`max_health`、`base_damage`、`bonus_per_matching_soul`、`base_heal`、`base_shield`、`base_amount`、`damage_per_stack`、`heal_per_stack`、`status_magnitude`、触发器 `magnitude` 运行期均向下取整（每跳不足 1 会变 0）；暴击率/倍率、冷却、概率、距离保留小数。
- 调试与顺序接口见 `指南/AI测试接口.md`（日志前缀 `ModLoader:`），常见报错排查见 `架构/Mod系统.md` §5。
