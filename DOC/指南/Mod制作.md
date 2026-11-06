# Mod 制作与打包

> 类型：指南 | 状态：部分实现（Phase 1 的 1～5）
> 何时读：制作、打包、调试 idle_around 的 mod
> 关键词：mod.json content.pck modkit patch 导出 覆盖 加载顺序
> 代码：`Scripts/mod/`、`Scripts/collection_db.gd`
> 相关：`架构/Mod系统.md`
> 核对：2026-11-06

## 1. 最小 mod

```text
user://mods/example_souls/
  mod.json
  content.pck
```

开发期可以不放 `content.pck`，直接把内容放在目录里（loose 模式）；发布前再打包。loose 模式不经过 Godot 导入流程，贴图/场景资源可能不可用，只建议用来调数据。

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
		"id": "example_souls:fire_wolf",
		"path": "content/monsters/fire_wolf_data.tres"
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
    "res://game/content/effects/burn_tick.tres"
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
| `content.souls` | 否 | 魂灵条目：`id` + `path` |
| `content.monsters` | 否 | 怪物条目：`id` + `path` |
| `content.cues` | 否 | Cue 条目：`tag` + `scene`；启动时注册到 `GameplayCueManager` |
| `overrides` | 否 | 覆盖的原版 `res://` 路径，必须存在 |

## 3. 内容路径与 ID

- 魂灵/怪物 ID：`<mod_id>:<local_id>`，例如 `example_souls:fire_wolf_soul`。
- 技能 `SkillDefinition.id`：`<mod_id>_<local_id>`，例如 `example_souls_fire_wolf_skill`；新技能不加前缀会和别的 mod 的 `Skill.<id>` 撞车。
- Cue 标签：`Cue.Mod.<PascalModId>.<Name>`，例如 `Cue.Mod.ExampleSouls.Fire`。`<PascalModId>` 是 mod id 的 PascalCase 形式（`example_souls` → `ExampleSouls`），不属于本 mod 命名空间的标签会被拒绝。
- Cue 场景根节点必须继承 `GameplayCueNotify`；注册发生在启动时，运行期不能新增或替换 Cue。
- Cue 标签不要求登记到游戏的 `godot_gas/tag_registry.tres`，运行时按字符串匹配；modkit 的标签选择器只列本机 registry，可以直接编辑 `.tres` 文本，或在 modkit 的 registry 里临时加同名标签。
- `path` 可以写相对路径（相对于 mod 根目录），也可以写 `res://mods/<mod_id>/...`；loose 模式会自动映射到 `user://mods/<mod_id>/...`。
- 内容路径必须落在本 mod 的命名空间目录下。

## 4. 用 Godot 4.7 打包

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

- 在 modkit 里直接修改原路径的资源，例如 `res://game/content/effects/burn_tick.tres`。
- 在 `mod.json` 的 `overrides` 里声明这些路径。
- 后加载的 mod 覆盖先加载的；同一路径被多个 mod 声明覆盖会出现在 `ModLoader.get_errors()`。
- 不允许覆盖 `project.godot`、`.godot/`、YARD registry 和 `Scripts/mod/`；这些路径会被拒绝。

## 6. 加载顺序

- 先满足 `dependencies`，再满足 `load_after`，其余按 mod id 字母序。
- 循环依赖会记录错误，但不会导致启动失败。
- 启用状态和已知 mod 记录在 `user://mods.cfg`。

## 7. 调试

- `TestAPI.get_mod_list()`：mod 概况、是否加载、内容数量、错误。
- `TestAPI.get_mod_errors()`：加载器、内容合并和 Cue 注册诊断汇总。
- `TestAPI.get_mod_cues()`：mod Cue 的标签、来源、路径、是否注册成功。
- `TestAPI.is_mod_cue_registered(tag)`：单个 mod Cue 是否已注册。
- `TestAPI.set_mod_enabled(id, enabled)`：写启用状态；重启后生效。
- `TestAPI.get_orphaned_records()`：当前存档里因缺失 mod 内容而保留的记录。
- 日志前缀：`ModLoader:`。

## 8. 当前限制

- Cue 只在启动时注册；运行期不能新增/替换，也不能注销。标签必须属于本 mod 的 `Cue.Mod.<PascalModId>.` 命名空间，场景根节点必须是 `GameplayCueNotify`。
- 没有 mod 管理 UI；用 `user://mods.cfg` 或 TestAPI 改启用状态。
- 没有 Workshop 上传/订阅；先手动放目录。
- 允许 PCK 内的 GDScript，Godot 没有沙箱；只加载可信 mod。
