# Mod 系统与创意工坊

> 类型：设计 | 状态：部分实现（内置 core mod 已接入；Steam 后置）
> 何时读：改 mod 加载、内容注册、存档兼容，或准备接 Steam 创意工坊
> 关键词：mod ModLoader manifest PCK 创意工坊 Workshop content_id orphaned 加载顺序 内置 core content_namespace content_root
> 代码：`Scripts/mod/`、`Scripts/collection_db.gd`、`Scripts/save/`、`project.godot`、`base_mods/core/mod.json`
> 相关：`架构/存档.md`、`架构/扩展点.md`、`指南/Mod制作.md`
> 不覆盖：Steamworks 后台配置、GodotSteam 完整 API
> 核对：2026-11-07

## 1. 目标与边界

- **创意工坊只负责分发和订阅**：托管文件、下载到 `steamapps/workshop/content/<appid>/<fileid>/`、更新、展示、举报/审核。它不负责游戏如何加载和注册内容。
- **mod 系统负责游戏侧**：发现 mod、校验、挂载、排序、冲突检测、内容注册、存档兼容。
- **两者解耦**：本地 `user://mods/` 和 Workshop 下载目录都产出同样的 `mod.json + content.pck`，走同一套加载逻辑。
- 当前只做本地 mod；Steam 后置，没有 App ID 也能开发和测试。

## 2. 为什么用内置 core manifest 代替 YARD registry

- 官方内容和第三方 mod 走同一条发现、校验、加载、注册管线，避免“原版一套、mod 一套”。
- YARD registry 是编辑器烘焙的，运行时只读，无法追加条目；现已删除 `addons/yard/` 和 `game/content/Collection/*_registry.tres`。
- `CollectionDB` 不再 `preload` registry，完全读取 `ModLoader.get_soul_entries()` / `get_monster_entries()`。
- 官方内容清单在 `base_mods/core/mod.json`；新增魂灵/怪物/Cue 时改 manifest，不再依赖编辑器扫描。
- `content_namespace = "global"` 让 core 保留原 ID（如 `xiao_lu_soul`、`fu_data`），旧存档不需要迁移。
- 对外 API 不变：`get_soul()`、`get_soul_ids()`、`get_monster()`、`pick_random_monster()` 仍由 `CollectionDB` 提供。

## 3. 架构

```text
ModLoader（autoload，最先）
  发现 res://base_mods/<id>/mod.json（内置 core）
  发现 user://mods/<id>/mod.json（第三方）
  → 校验 / 依赖排序 / 冲突检测
  → 先挂载全部 PCK，再统一加载内容资源
  → 产出 souls / monsters / cues 条目
        │
        ├─ cues ──▶ GameplayCueManager（项目包装，继承 addon 的管理器）
        │              → 注册 core + 第三方 mod Cue
        │
        ▼
CollectionDB（autoload）
  全部来自 ModLoader 条目
  → 给 SoulData/MonsterData 写 content_id
        │
        ▼
SaveManager
  content_id 优先；缺失内容写 orphaned
```

- `ModLoader` 不做玩法逻辑，只提供 mod 概况、内容条目和启用/顺序配置。
- `CollectionDB` 仍是唯一内容入口；core 和 mod 内容一样被图鉴、刷怪、仓库使用。
- `GameplayCueManager` 的项目包装（`Scripts/mod/cue_manager_mod.gd`）只在基类加载完内置 registry 后注册 ModLoader 的 Cue；项目内置 `godot_gas/cue_registry.tres` 现在为空。
- 内置 `core` 固定启用、固定加载顺序第一，玩家不能禁用或把它排到第三方 mod 后面。
- Steam 接入不在当前范围。

## 4. 启动时序

1. `ModLoader._init()`：加载 `user://mods.cfg`（启用状态和 `[order]`），先扫描 `res://base_mods/*/mod.json`，再扫描 `user://mods/*/mod.json`；校验、依赖排序后先挂载全部 PCK，再统一加载 manifest 列出的内容资源。
2. `GameGlobal`、`GBIS` 等原有 autoload 按原顺序启动。
3. `GameplayCueManager._ready()`（项目包装）：先让基类加载内置 `cue_registry`（当前为空），再注册 `ModLoader` 校验通过的 core 和第三方 mod Cue。
4. `CollectionDB._ready()`：从 `ModLoader` 的 souls/monsters 条目构建目录，写 `content_id`。
5. `SaveManager` 等一帧后读档；找不到的内容进 `orphaned`。
6. 主场景启动。

约束：

- 必须在 autoload 的 `_init()` 里挂载 PCK；挂载晚了，之前 `preload()` 的资源不会替换。
- 内容加载必须在所有 PCK 挂载完之后做。否则 core 先加载的资源会进缓存，第三方 PCK 对 `res://base_mods/core/...` 的覆盖不生效。
- 没有卸载 API，启用/禁用/改顺序后必须重启。
- 挂载后 `DirAccess` 不会列出 PCK 内部目录，所以内容路径由 `mod.json` 显式列出，不扫描 PCK。
- 内置 mod 只支持 loose 目录，不支持 `content.pck`，保证任何导出配置下都能通过 `res://` 读取。
- `GameplayCueManager` 的 autoload 路径已改为项目包装。如果禁用再启用 GodotGAS 插件，插件会把 autoload 改回 `addons/GodotGAS/managers/gameplay_cue_manager.gd`，需要手动改回 `Scripts/mod/cue_manager_mod.gd`。

## 5. Mod 来源与包结构

| 来源 | 目录 | 打包方式 | 说明 |
|---|---|---|---|
| 内置 `core` / 官方内容包 | `res://base_mods/<id>/` | 只支持 loose | 随主包发布，固定启用、排序最前 |
| 第三方 mod | `user://mods/<id>/` | `content.pck` 或 loose | 玩家安装，可启用/禁用/排序 |

内置 core：

```text
res://base_mods/core/
  mod.json
  souls/
  monsters/
  effects/
  cues/
```

第三方 mod：

```text
user://mods/example_souls/
  mod.json
  content.pck        # 可选；没有则按 loose 目录加载，便于开发
```

PCK 内部内容放在命名空间目录：

```text
res://mods/example_souls/content/souls/fire_wolf_soul.tres
res://mods/example_souls/content/monsters/fire_wolf_data.tres
```

- 正式发布用 PCK；loose 目录只用于开发，贴图不会走 Godot 导入流程。
- `mod.json` 必须在 PCK 外面，`ModLoader` 在挂载前读取它。
- 内置 mod 的 manifest 可以用 `content_root` 指向 `res://` 下的内容根；第三方 mod 不允许使用这个字段，必须把内容放在自己的命名空间目录下。
- core 已经物理迁移到 `base_mods/core/`，不再填写 `content_root`，直接使用默认根目录。
- Workshop 以后只需把 `mod.json + content.pck` 放进 item 目录，加载逻辑不变。

## 6. 内容 ID 与加载规则

- 内置 core 在 manifest 里声明 `content_namespace: "global"`，内容 ID 沿用原值（如 `xiao_lu_soul`、`fu_data`），技能 ID 和 Cue 标签也不加前缀（如 `Cue.Status.Burn`）。
- 第三方 mod 内容 ID：`<mod_id>:<local_id>`；技能 `SkillDefinition.id`：`<mod_id>_<local_id>`，因为 `ability_tag = "Skill." + id`，重复会互相顶掉。
- 第三方 Cue 标签：`Cue.Mod.<PascalModId>.<Name>`，例如 `example_souls` → `Cue.Mod.ExampleSouls.Fire`；不属于本 mod 命名空间的标签会被拒绝。`GameplayCueManager` 的项目包装在基类加载完内置 registry 后注册所有 ModLoader Cue，场景根节点必须继承 `GameplayCueNotify`；已存在的标签不会被覆盖。
- `content_namespace: "global"` 和 `content_root` 只允许内置来源；第三方写了会被拒绝并记入 `ModLoader.get_errors()`。
- 加载顺序：内置 mod 固定在最前；第三方按用户在 Mod 窗口排的基础顺序，存在 `user://mods.cfg` 的 `[order]`。`dependencies` 是硬依赖，缺失/禁用时依赖方不加载；`load_after` 是软顺序。两者都会覆盖用户顺序，冲突时以依赖为准。
- 路径覆盖：所有 PCK 先挂载，再加载内容；后挂载的 PCK 可以覆盖先挂载的资源。core 内容在 `res://base_mods/core/...`，第三方覆盖这些路径即可，但要在 `overrides` 里声明。
- 冲突检测：重复内容 ID、重复 cue tag、同一路径被多个 mod 声明覆盖在加载阶段记录；重复 skill id 在 `CollectionDB` 构建目录时补充。都会出现在 `ModLoader.get_errors()`。
- 内容路径必须落在该 mod 的根目录下：第三方是 `res://mods/<id>/` 或 `user://mods/<id>/`；内置是 `res://base_mods/<id>/` 或 manifest 的 `content_root`。`overrides` 是唯一允许指向其他 `res://` 路径的入口。

## 7. 存档兼容与缺失内容

- 存档仍然只存字符串 ID，不存资源路径。
- core 的 ID 保持原值，旧存档不需要迁移；第三方 mod 使用带前缀的 ID。
- `SoulData` 和 `MonsterData` 新增 `content_id`；`SaveCodec` 编码时优先用它，`item_name` 只做旧档兜底。
- 这样两个 mod 的魂灵即使显示名相同，也不会串档。
- **缺失内容不能静默丢**：读档时找不到的内容记录写入 `orphaned` 段；写档时原样带回。重新启用 mod 后，下一次读档会尝试放回原容器/仓库。
- `version` 仍是 1。

## 8. 当前实现范围（Phase 1 + 内置 core）

- 已做：`mod.json` schema、`content_namespace` / `content_root`、`ModLoader`、内置 `res://base_mods` 与 `user://mods` 双来源发现、PCK/loose 挂载、两段式挂载与内容加载、依赖排序、冲突检测、`CollectionDB` 统一目录、`content_id`、`orphaned` 存档保护、core/mod Cue 注册、`ModWindow` 管理窗口、加载顺序调整。
- 已删除：`addons/yard/`、`game/content/Collection/soul_registry.tres`、`monster_registry.tres`。
- 未做：Steam 订阅与发布。
- 新增功能后按项目约定同步 `Scripts/test_api.gd` 和 `DOC/指南/AI测试接口.md`。

### 8.1 Mod 管理窗口

- 主界面第 9 个按钮打开；`Windows/ModWindow/mod_window.gd` 用代码搭建界面，不依赖场景布局。
- “Mod 列表”标签页显示名称、id、来源（内置/本地）、版本、作者、描述、加载状态、内容数量、运行时顺序和逐条错误。
- 内置 core 行禁用启用勾选框，显示“内置”；第三方 mod 勾选启用状态调用 `ModLoader.set_mod_enabled()` 写 `user://mods.cfg`；运行期不重载，重启后生效。窗口会标出未生效的改动。
- “打开 mod 目录”用 `OS.shell_open()` 打开 `user://mods`，方便放 loose mod；内置 core 在游戏包内。

### 8.2 加载顺序

- “加载顺序”标签页用上移/下移调整基础顺序，写入 `user://mods.cfg` 的 `[order] list`；运行期不重排，重启后生效。
- 内置 mod 固定在最前，上/下移按钮禁用；`set_mod_order()` 也会把它们归位。
- 顺序只是第三方 mod 的基础顺序；`dependencies` 和 `load_after` 仍会在排序时把依赖方提前。Mod 列表显示的是本次实际加载顺序。
- `get_mod_order()` 返回用户顺序（内置在前），`get_mod_load_order()` 返回实际加载顺序；两者都可能因依赖而不同。

### 8.3 示例 mod/modkit

- 示例源码在 `mods/example_souls/`，按 `res://mods/example_souls/` 的运行时路径编写，包含魂灵、技能和自定义 Cue。
- `modkit/pack_example.gd` 用 `PCKPacker` 打包到 `user://mods/example_souls/`，并复制 `mod.json`；具体命令见 `指南/Mod制作.md` 的 4.1。
- `mods/` 和 `modkit/` 已从正式游戏导出中排除。

### 8.4 内置 core

- 清单在 `base_mods/core/mod.json`，当前 `souls` 20 条、`monsters` 2 条、`cues` 5 条；技能、触发器、effects 不单独登记，由资源内部引用。
- `content_namespace: "global"` 保留旧 ID；内容资源已经物理迁移到 `base_mods/core/` 的 `souls/`、`monsters/`、`effects/`、`cues/`。
- 官方 Cue 场景在 `base_mods/core/cues/`，逻辑脚本仍在 `game/battle/cues/`；`godot_gas/cue_registry.tres` 为空。
- 导出时 `export_presets.cfg` 的 `include_filter` 必须包含 `base_mods/*/mod.json`；`exclude_filter` 用 `mods/*,modkit/*`，不能写成 `*mods/*`，否则会误伤 `base_mods/`。

## 9. 安全边界

- PCK 可以包含并执行 GDScript，Godot 没有沙箱；允许 PCK 就等于允许代码 mod。
- 内置 `base_mods` 随主包发布，视为可信代码；`content_namespace: "global"` 和 `content_root` 只对它开放。
- 当前默认信任本地 mod，只在日志/测试接口暴露错误；正式上 Workshop 前需要加首次启用警告和基本校验。
- `overrides` 目前只做声明和冲突检查，不能阻止 PCK 里未声明的覆盖；需要严格限制时再解析 PCK 文件索引做白名单。

## 10. 后续：Steam 创意工坊

1. 加 GodotSteam GDExtension 和 `SteamService`：`steamInitEx`、`run_callbacks`、离线降级。
2. `WorkshopService`：订阅列表、`get_item_install_info`、未下载时 `download_item`、安装目录交给 `ModLoader`。
3. 更新检测：对比安装时间戳/manifest 版本，提示重启。
4. 发布：先用 `steamcmd +workshop_build_item` 或独立工具；稳定后再做游戏内 UGC 上传。
5. 需要 Steamworks App ID、Workshop 配置、法律协议和举报/下架流程。
