# Mod 系统与创意工坊

> 类型：设计 | 状态：部分实现（Phase 1 的 1～5 + 管理窗口/加载顺序）
> 何时读：改 mod 加载、内容注册、存档兼容，或准备接 Steam 创意工坊
> 关键词：mod ModLoader manifest PCK 创意工坊 Workshop content_id orphaned 加载顺序
> 代码：`Scripts/mod/`、`Scripts/collection_db.gd`、`Scripts/save/`、`project.godot`
> 相关：`架构/存档.md`、`架构/扩展点.md`、`指南/Mod制作.md`
> 不覆盖：Steamworks 后台配置、GodotSteam 完整 API
> 核对：2026-11-06

## 1. 目标与边界

- **创意工坊只负责分发和订阅**：托管文件、下载到 `steamapps/workshop/content/<appid>/<fileid>/`、更新、展示、举报/审核。它不负责游戏如何加载和注册内容。
- **mod 系统负责游戏侧**：发现 mod、校验、挂载、排序、冲突检测、内容注册、存档兼容。
- **两者解耦**：本地 `user://mods/` 和 Workshop 下载目录都产出同样的 `mod.json + content.pck`，走同一套加载逻辑。
- 当前只做本地 mod；Steam 后置，没有 App ID 也能开发和测试。

## 2. 为什么不能直接改 YARD registry

- `Scripts/collection_db.gd` 用 `preload` 读两份 YARD registry；`addons/yard/registry.gd` 在运行时把 UID 字典设为只读。
- YARD 的扫描和 ID 映射是编辑器烘焙的，运行时不能追加条目。
- 因此 mod 内容不进 YARD；`CollectionDB` 加载原版 registry 后，再合并 `ModLoader` 提供的运行时条目。
- 对外 API 不变：`get_soul()`、`get_soul_ids()`、`get_monster()`、`pick_random_monster()` 仍由 `CollectionDB` 提供。

## 3. 架构

```text
ModLoader（autoload，最先）
  发现 user://mods/<id>/mod.json
  → 校验 / 依赖排序 / 冲突检测
  → 有 content.pck 就 load_resource_pack()
  → 产出 souls / monsters / cues 条目
        │
        ├─ cues ──▶ GameplayCueManager（项目包装，继承 addon 的管理器）
        │              → 加载内置 registry 后追加 mod Cue
        │
        ▼
CollectionDB（autoload）
  原版 YARD registry + mod 条目
  → 给 SoulData/MonsterData 写 content_id
        │
        ▼
SaveManager
  content_id 优先；缺失内容写 orphaned
```

- `ModLoader` 不做玩法逻辑，只提供 mod 概况、内容条目和启用/顺序配置。
- `CollectionDB` 仍是唯一内容入口；mod 内容与普通内容一样被图鉴、刷怪、仓库使用。
- `GameplayCueManager` 的项目包装（`Scripts/mod/cue_manager_mod.gd`）只在基类加载完内置 registry 后追加 mod Cue，不参与内容目录和存档；这样不用改 `addons/`。
- Steam 接入不在当前范围。

## 4. 启动时序

1. `ModLoader._init()`：加载 `user://mods.cfg`（启用状态和 `[order]`），扫描 `user://mods/*/mod.json`，按用户基础顺序排序并挂载 PCK，加载 manifest 列出的内容资源。
2. `GameGlobal`、`GBIS` 等原有 autoload 按原顺序启动。
3. `GameplayCueManager._ready()`（项目包装）：先让基类加载内置 `cue_registry`，再追加 `ModLoader` 校验通过的 mod Cue。
4. `CollectionDB._ready()`：读原版 registry，合并 mod 条目，写 `content_id`。
5. `SaveManager` 等一帧后读档；找不到的内容进 `orphaned`。
6. 主场景启动。

约束：

- 必须在 autoload 的 `_init()` 里挂载 PCK；挂载晚了，之前 `preload()` 的资源不会替换。
- 没有卸载 API，启用/禁用/改顺序后必须重启。
- 挂载后 `DirAccess` 不会列出 PCK 内部目录，所以内容路径由 `mod.json` 显式列出，不扫描 PCK。
- `GameplayCueManager` 的 autoload 路径已改为项目包装。如果禁用再启用 GodotGAS 插件，插件会把 autoload 改回 `addons/GodotGAS/managers/gameplay_cue_manager.gd`，需要手动改回 `Scripts/mod/cue_manager_mod.gd`。

## 5. Mod 来源与包结构

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
- Workshop 以后只需把 `mod.json + content.pck` 放进 item 目录，加载逻辑不变。

## 6. 内容 ID 与加载规则

- mod 内容 ID：`<mod_id>:<local_id>`；原版 ID 不带冒号，互不冲突。
- 技能 `SkillDefinition.id`：`<mod_id>_<local_id>`，因为 `ability_tag = "Skill." + id`；重复 ID 会互相顶掉。
- Cue 标签：`Cue.Mod.<PascalModId>.<Name>`，例如 `example_souls` → `Cue.Mod.ExampleSouls.Fire`；标签不属于本 mod 命名空间时拒绝加载。`GameplayCueManager` 的项目包装在基类加载完内置 registry 后注册 mod Cue，场景根节点必须继承 `GameplayCueNotify`；已存在的标签不会被覆盖。
- 加载顺序：用户在 Mod 窗口里排的基础顺序存在 `user://mods.cfg` 的 `[order]`；`dependencies` 是硬依赖，缺失/禁用时依赖方不加载；`load_after` 是软顺序。两者都会覆盖用户顺序，冲突时以依赖为准。后挂载的 mod 覆盖先挂载的。
- 冲突检测：重复内容 ID、重复 cue tag、同一路径被多个 mod 声明覆盖在加载阶段记录；重复 skill id 在 `CollectionDB` 合并阶段补充。都会出现在 `ModLoader.get_errors()`。
- mod 内容路径必须落在该 mod 的命名空间目录下；只有 `overrides` 可以指向原版 `res://` 路径。

## 7. 存档兼容与缺失内容

- 存档仍然只存字符串 ID，不存资源路径。
- `SoulData` 和 `MonsterData` 新增 `content_id`；`SaveCodec` 编码时优先用它，`item_name` 只做旧档兜底。
- 这样两个 mod 的魂灵即使显示名相同，也不会串档。
- **缺失内容不能静默丢**：读档时找不到的内容记录写入 `orphaned` 段；写档时原样带回。重新启用 mod 后，下一次读档会尝试放回原容器/仓库。
- 原版 ID 不变，旧存档不需要迁移；`version` 仍是 1。

## 8. 当前实现范围（Phase 1 的 1～5 + 管理窗口/加载顺序）

- 已做：`mod.json` schema、`ModLoader`、`user://mods` 发现、PCK/loose 挂载、依赖排序、冲突检测、`CollectionDB` 合并、`content_id`、`orphaned` 存档保护、mod Cue 注册、`ModWindow` 管理窗口、加载顺序调整。
- 未做：示例 mod/modkit、Steam 订阅与发布。
- 新增功能后按项目约定同步 `Scripts/test_api.gd` 和 `DOC/指南/AI测试接口.md`。

### 8.1 Mod 管理窗口

- 主界面第 9 个按钮打开；`Windows/ModWindow/mod_window.gd` 用代码搭建界面，不依赖场景布局。
- “Mod 列表”标签页显示名称、id、版本、作者、描述、加载状态、内容数量、运行时顺序和逐条错误。
- 勾选启用状态调用 `ModLoader.set_mod_enabled()` 写 `user://mods.cfg`；运行期不重载，重启后生效。窗口会标出未生效的改动。
- “打开 mod 目录”用 `OS.shell_open()` 打开 `user://mods`，方便放 loose mod。

### 8.2 加载顺序

- “加载顺序”标签页用上移/下移调整基础顺序，写入 `user://mods.cfg` 的 `[order] list`；运行期不重排，重启后生效。
- 顺序只是基础顺序；`dependencies` 和 `load_after` 仍会在排序时把依赖方提前。Mod 列表显示的是本次实际加载顺序。
- `get_mod_order()` 返回用户顺序，`get_mod_load_order()` 返回实际加载顺序；两者都可能因依赖而不同。

## 9. 安全边界

- PCK 可以包含并执行 GDScript，Godot 没有沙箱；允许 PCK 就等于允许代码 mod。
- 当前默认信任本地 mod，只在日志/测试接口暴露错误；正式上 Workshop 前需要加首次启用警告和基本校验。
- `overrides` 目前只做声明和冲突检查，不能阻止 PCK 里未声明的覆盖；需要严格限制时再解析 PCK 文件索引做白名单。

## 10. 后续：Steam 创意工坊

1. 加 GodotSteam GDExtension 和 `SteamService`：`steamInitEx`、`run_callbacks`、离线降级。
2. `WorkshopService`：订阅列表、`get_item_install_info`、未下载时 `download_item`、安装目录交给 `ModLoader`。
3. 更新检测：对比安装时间戳/manifest 版本，提示重启。
4. 发布：先用 `steamcmd +workshop_build_item` 或独立工具；稳定后再做游戏内 UGC 上传。
5. 需要 Steamworks App ID、Workshop 配置、法律协议和举报/下架流程。
