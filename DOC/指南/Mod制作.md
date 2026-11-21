# Mod 制作与打包

> 类型：指南 | 状态：部分实现（内置 core 已接入） | 核对：2026-11-21
> 何时读：制作、打包、调试 idle_around 的 mod，或新增官方内容
> 关键词：mod.json content.pck modkit 示例 mod pack_example patch 导出 覆盖 加载顺序 内置 core content_root content_namespace validate_core_manifest manifest 校验 内容 ID 技能 ID 命名 PascalCase content_id 魂器 vessels
> 代码：`Scripts/mod/`、`Scripts/collection_db.gd`、`base_mods/core/mod.json`
> 相关：`架构/Mod系统.md`
> 核对：2026-11-15

## 1. 最小 mod

```text
user://mods/example_souls/
  mod.json
  content.pck
```

开发期可以不放 `content.pck`，直接把内容放在目录里（loose 模式）；发布前再打包。loose 模式不经过 Godot 导入流程，贴图/场景资源可能不可用，只建议用来调数据。

本工程自带示例源码 `mods/example_souls/` 和一键打包脚本 `EngineTools/modkit/pack_example.gd`，见 4.1。官方内容不走 `user://mods`，而是内置 `base_mods/core/mod.json`，见第 9 节；第三方 mod 不要填写 `content_namespace: "global"` 或 `content_root`，这两个字段只对内置 mod 开放。

## 2. mod.json

```json
{
  "schema": 1,
  "id": "example_souls",
  "name": "Example Souls",
  "version": "1.0.0",
  "author": "someone",
  "description": "示例 mod",
  "game_version": { "min": "0.1.0", "max": "0.2.0" },
  "load_after": [],
  "dependencies": [],
  "content": {
	"souls": [
	  {
		"id": "example_souls:fire_wolf_soul",
		"path": "content/souls/fire_wolf_soul.tres"
	  }
	],
	"monsters": [
	  {
		"id": "example_souls:fire_wolf_monster",
		"path": "content/monsters/fire_wolf_monster.tres"
	  }
	],
	"cues": [
	  {
		"tag": "Cue.Mod.ExampleSouls.Fire",
		"scene": "content/cues/fire_cue.tscn"
	  }
	]
  },
  "overrides": [
    "res://base_mods/core/effects/burn_tick.tres"
  ]
}
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `schema` | 否 | 当前只支持 `1`；省略按 1 处理 |
| `id` | 是 | 小写 snake_case，全局唯一 |
| `name` / `version` / `author` / `description` | 否 | 展示用 |
| `game_version` | 否 | `min` / `max` 为包含边界；不兼容时不加载 |
| `load_after` | 否 | 软顺序；目标不存在时忽略 |
| `dependencies` | 否 | 硬依赖；缺失或禁用时本 mod 不加载 |
| `content_namespace` | 否 | 默认 `"mod"`；`"global"` 只允许内置 mod，第三方填写会被拒绝 |
| `content_root` | 否 | 只允许内置 mod；指向 `res://` 下的内容根目录，空则用 `res://base_mods/<id>/` |
| `content.souls` | 否 | 魂灵条目：`id` + `path` |
| `content.monsters` | 否 | 怪物条目：`id` + `path` |
| `content.vessels` | 否 | 魂器条目：`id` + `path`（`SoulVesselData`） |
| `content.cues` | 否 | Cue 条目：`tag` + `scene`；启动时由 `ModCueRegistrar` 注册到 `GameplayCueManager` |
| `overrides` | 否 | 覆盖的原版 `res://` 路径，必须存在 |

`game_version` 比较按点分段，缺省段按 0 处理（`0.2` 等价 `0.2.0`）。

## 3. 内容路径与 ID

### 3.1 命名规则

- 资源 ID（`content_id`、`local_id`）统一小写 snake_case：`^[a-z][a-z0-9_]*$`。
- GAS 标签每一段用 PascalCase；`GameplayTagRegistry` 不接受下划线，也不允许段首小写。
- 分隔符固定：mod 内容 ID 用 `:` 分隔命名空间，GAS 标签用 `.` 分隔层级，不要混用。

| 类型 | 规则 | 示例 |
|---|---|---|
| mod id | `^[a-z][a-z0-9_]{2,63}$` | `example_souls` |
| core 魂灵 ID | `<name>_soul` | `<name>_soul` |
| core 怪物 ID | `<name>_monster` | `<name>_monster` |
| core 魂器 ID | `<name>_vessel` | `<name>_vessel` |
| 第三方魂灵/怪物/魂器 ID | `<mod_id>:<name>_<kind>` | `example_souls:fire_wolf_soul` |
| core 技能 ID | 魂灵 ID 去掉 `_soul` 后转 PascalCase | `<PascalName>` → `Skill.<PascalName>` |
| 第三方技能 ID | `Mod.<PascalModId>.<PascalName>` | `Mod.ExampleSouls.FireWolf` → `Skill.Mod.ExampleSouls.FireWolf` |
| core Cue | `Cue.<Category>.<Name>` | `Cue.Status.Burn` |
| 第三方 Cue | `Cue.Mod.<PascalModId>.<Name>` | `Cue.Mod.ExampleSouls.Fire` |

- 魂灵/怪物 ID 是**存档键**：已发布的内容 ID 不要改名。
- 技能 `SkillDefinition.id` 存的是 `ability_tag` 的后缀（不含 `Skill.`），所以必须满足 GAS 标签格式。留空时 `ModLoader` 按魂灵的 `content_id` 自动派生；core 技能 ID 由 `CoreContentValidator` 强制与魂灵 ID 对应。
- Cue 场景根节点必须继承 `GameplayCueNotify`；注册发生在启动时，运行期不能新增或替换 Cue。
- Cue 标签不要求登记到游戏的 `godot_gas/tag_registry.tres`，运行时按字符串匹配；modkit 的标签选择器只列本机 registry，可以直接编辑 `.tres` 文本，或在 modkit 的 registry 里临时加同名标签。
- `path` 可以写相对路径（相对于 mod 根目录），也可以写 `res://mods/<mod_id>/...`；loose 模式会自动映射到 `user://mods/<mod_id>/...`。
- 内容路径必须落在本 mod 的命名空间目录下。

## 4. 用 Godot 4.7 打包

### 4.1 示例 mod 一键打包

示例源码在 `mods/example_souls/`，包含一颗魂灵、一条技能和一个自定义 Cue。它按 `res://mods/example_souls/` 的运行时路径编写，所以可以直接打进 PCK。

在项目根目录运行：

```text
"U:\Godot_ver\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" ^
  --headless --path "U:\Godot_Project\idle_around" ^
  --script res://EngineTools/modkit/pack_example.gd
```

脚本会生成 `user://mods/example_souls/content.pck` 并把 `mod.json` 复制到旁边。打包脚本走 `--script` 模式；`SaveManager` 检测到没有主场景会跳过读档，不会碰存档。重启游戏后，Mod 窗口里能看到 `Example Souls`；用 `TestAPI.add_soul(&"example_souls:fire_wolf_soul")` 可以把魂灵放进仓库。

改一个新 mod 时，复制 `mods/example_souls/` 为 `mods/<mod_id>/`，同步修改 `mod.json` 的 `id`、内容 ID、技能 ID（`Mod.<PascalModId>.<PascalName>`）和 Cue 前缀，再复制或改造 `pack_example.gd` 里的 `MOD_ID`。`mods/` 和 `EngineTools/modkit/` 不会打进正式游戏包。

### 4.2 用 patch 导出

1. 从当前工程复制一份 modkit，保持 Godot 4.7.x；不要用不同小版本。
2. 在 modkit 里新建 `res://mods/<mod_id>/`，放入内容资源。
3. 写 `mod.json`；它和 PCK 一起发布，不要打进 PCK。
4. 导出预设的 Patching → Base Packs 选择游戏导出的 base `.pck`，导出 patch PCK；这样只包含新增/修改的文件，不会把基础脚本重复打包。
5. 把 `mod.json` 和 `content.pck` 放进同一个文件夹。

注意：

- 游戏的 `export_presets.cfg` 要保持 `binary_format/embed_pck=false`，否则没有独立 base PCK 可供 patch 导出。
- 不要用 delta 编码；普通 patch 足够，delta 对 base 版本要求过严。
- 不要加密 mod PCK。
- 游戏更新后，用新版本重新导出 mod。

## 5. 覆盖原版

- 在 modkit 里直接修改原路径的资源，例如 `res://base_mods/core/effects/burn_tick.tres`。
- 在 `mod.json` 的 `overrides` 里声明这些路径。
- 所有 PCK 先挂载、再加载内容，所以后加载的 mod 能覆盖先加载的资源；同一路径被多个 mod 声明覆盖会出现在 `ModLoader.get_errors()`。
- 官方资源路径以 `res://base_mods/core/` 为准；override 目标不存在时 `ModLoader` 会报错，不会静默失效。
- 不允许覆盖 `project.godot`、`.godot/`、`base_mods/*/mod.json` 和 `Scripts/mod/`；这些路径会被拒绝。

## 6. 加载顺序

- 基础顺序在 Mod 窗口的“加载顺序”页用上移/下移调整，存在 `user://mods.cfg` 的 `[order]`；没有列出的 mod 按 id 追加到末尾。
- 排序时先满足 `dependencies`，再满足 `load_after`，其余按基础顺序；两者会覆盖用户顺序，冲突时以依赖为准。
- 顺序改动重启后生效；Mod 列表里的“顺序 N”是本次实际加载顺序。
- 循环依赖会记录错误，但不会导致启动失败。
- 启用状态和已知 mod 记录在 `user://mods.cfg`。

## 7. 调试

- `TestAPI.get_mod_list()`：mod 概况（含 `source` / `builtin` / `locked`）、是否加载、内容数量、错误。
- `TestAPI.get_mod_errors()`：加载器、内容合并和 Cue 注册诊断汇总。
- `TestAPI.is_builtin_mod(id)`：是否为内置 mod。
- `TestAPI.get_mod_content_ids(id)`：该 mod 注册的 souls / monsters / vessels / cues ID 列表。
- `TestAPI.get_skill_tags()`：所有魂灵的 `content_id`、技能 ID 和 `ability_tag`，用于核对技能命名。
- `TestAPI.validate_core_manifest()`：校验 `base_mods/core/mod.json` 与内容文件是否一致，并检查资源是否误设中文 `resource_name`；返回错误列表。
- `TestAPI.get_mod_cues()`：mod Cue 的标签、来源、路径、是否注册成功。
- `TestAPI.is_mod_cue_registered(tag)`：单个 mod Cue 是否已注册。
- `TestAPI.set_mod_enabled(id, enabled)`：写启用状态；重启后生效。
- `TestAPI.get_orphaned_records()`：当前存档里因缺失 mod 内容而保留的记录。
- 主界面“Mod”按钮打开管理窗口，可查看状态/错误、启用/禁用（重启生效）、调整加载顺序、打开 mod 目录。
- `TestAPI.get_mod_order()` / `TestAPI.get_mod_load_order()` / `TestAPI.set_mod_order()`：分别查看用户顺序、实际加载顺序、写入顺序。
- 日志前缀：`ModLoader:`。

## 8. 当前限制

- Cue 只在启动时注册；运行期不能新增/替换，也不能注销。第三方 Cue 标签必须属于本 mod 的 `Cue.Mod.<PascalModId>.` 命名空间；内置 core 使用全局标签。场景根节点必须是 `GameplayCueNotify`。
- 加载顺序可以在 Mod 窗口调整，但内置 mod 固定最前，`dependencies` / `load_after` 仍会覆盖第三方顺序；改动重启生效。启用状态可以在 Mod 窗口、`user://mods.cfg` 或 TestAPI 改。
- 没有 Workshop 上传/订阅；先手动放目录。
- 允许 PCK 内的 GDScript，Godot 没有沙箱；只加载可信 mod。

## 9. 官方内置内容（core）

- 清单：`base_mods/core/mod.json`；内容资源已经物理迁移到 `base_mods/core/` 的 `souls/`、`monsters/`、`vessels/`、`effects/`、`cues/`，manifest 不再填写 `content_root`。
- 当前条目：`souls` 19 条、`monsters` 2 条、`vessels` 1 条、`cues` 5 条。技能、触发器、effects 不单独登记，由魂灵/技能资源内部引用。
- 新增官方魂灵：把 `.tres` 放到 `base_mods/core/souls/<name>/`，在 `content.souls` 加 `{ "id": "<id>", "path": "souls/<name>/<file>.tres" }`。
- 新增官方怪物：数据放 `base_mods/core/monsters/<name>/`，在 `content.monsters` 加 `{ "id": "<id>", "path": "monsters/<name>/<file>.tres" }`；`display_name` / `max_health` / `attack_range` / `move_speed` / `spawn_distances` / `icon` / `battle_scene` 都配在 `MonsterData`，战斗场景不再写这些字段。
- 新增官方魂器：数据放 `base_mods/core/vessels/<name>/`，在 `content.vessels` 加 `{ "id": "<id>", "path": "vessels/<name>/<file>.tres" }`；字段见 `魂灵/魂器.md`，`item_name` / `category = "VESSEL"` / `vessel_kind` / 内部容器尺寸 / 效果都配在 `SoulVesselData`。
- 新增官方 Cue：场景放 `base_mods/core/cues/`，逻辑脚本可放 `game/battle/cues/`，在 `content.cues` 加 `{ "tag": "...", "scene": "cues/<file>.tscn" }`。
- 官方 ID 保持原值，不要加 `core:` 前缀；存档以这些 ID 为键。
- 内置 mod 只能 loose，不能把 `content.pck` 放进 `base_mods/`。
- 导出：`include_filter` 必须包含 `base_mods/*/mod.json`；`exclude_filter` 用 `mods/*,EngineTools/*`，不要用 `*mods/*`。
- 改完官方内容后跑 `EngineTools/modkit/validate_core_manifest.gd`，或调用 `TestAPI.validate_core_manifest()`，检查 manifest 是否漏登记、路径不存在和中文 `resource_name`。校验器读 `.tres` 文本而不是 `load()` 资源：`ItemData` 依赖 GBIS 等 autoload，modkit 的 `--script` 模式编译不了。
- 技能由 `SkillDefinition.steps` 组成；步骤类型、`target_rule` 与字段不一致（例如 `UnitSkillStep` 配 `SoulTargetRule`、`SoulSkillStep` 没有任何时长）会在 ModLoader 加载时报错。执行器字段也会校验：`StatusApplyExecution.attribute_name` 必须是 `burn/poison/regen`，伤害/治疗/护盾数值不能为负。校验失败的条目不会注册（不进入图鉴/刷怪池，mod 内容计数也不增加）；看 `ModLoader.get_errors()` 或 ModWindow。未知 manifest 字段、`content.*` 未知段只记 warning（`ModLoader.get_warnings()`），不阻止加载。
- 落地数值请写整数：`max_health`、`base_damage`、`bonus_per_matching_soul`、`base_heal`、`base_shield`、`base_amount`、`damage_per_stack`、`heal_per_stack`、`status_magnitude`、触发器 `magnitude`。写小数也能加载，但运行时会向下取整；每跳总量不足 1 点会变成 0，例如 `heal_per_stack = 0.5` + 1 层生命再生不产生治疗。暴击率/倍率、比例、冷却、概率、距离仍用小数。
