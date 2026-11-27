# Mod 系统与创意工坊

> 类型：实现 | 状态：部分实现（内置 core 已接入；Steam 后置） | 核对：2026-11-27
> 何时读：改 ModLoader 启动时序、内容注册校验、覆盖与冲突检测、Mod 窗口、加载顺序或 Steam 接入规划
> 关键词：ModLoader ModCueRegistrar ContentKindSpec PCK manifest overrides 加载顺序 orphaned Steam 常见排查
> 代码：`Scripts/mod/`、`Scripts/collection_db.gd`、`Scripts/save/`、`base_mods/core/mod.json`、`Windows/ModWindow/`
> 相关：`指南/Mod制作.md`、`架构/存档.md`、`指南/扩展点.md`、`指南/AI测试接口.md`
> 不覆盖：`mod.json` 完整字段、命名规则表、打包命令与 core 新增步骤（权威见 `指南/Mod制作.md`）

## 符号地图

| 文件 | 核心入口 | 职责 |
|---|---|---|
| `Scripts/mod/mod_loader.gd` | `get_mods` / `get_*_entries` / `get_errors` | 两段式发现、PCK 挂载、排序与注册 |
| `Scripts/mod/mod_cue_registrar.gd` | `register_cue` / `get_mod_cues` | Mod 特效 Cue 注册进 GAS |
| `Scripts/collection_db.gd` | `get_soul` / `get_monster` / `get_vessel` / `is_seen` | 从 ModLoader 构建内容索引与见闻 |
| `base_mods/core/mod.json` | — | 内置官方内容唯一清单真相 |

## 1. 目标、架构与替代 YARD

- **解耦边界**：创意工坊仅负责分发与订阅，游戏侧由 `ModLoader` 统一处理发现、校验、挂载、排序、冲突检测与注册；本地 `user://mods/` 与未来 Workshop 目录均产出 `mod.json + content.pck`，走同一管线。
- **内置 core 替代 YARD**：已删除 `addons/yard/` 与 `*_registry.tres`。官方内容经 `base_mods/core/mod.json`（`content_namespace = "global"` 保留无前缀原 ID）与第三方 mod 走同一条加载链；`CollectionDB` 完全从 `ModLoader` 构建索引，对外 API 不变。

```text
ModLoader (_init: 发现 core + user://mods → 校验/排序 → 全挂载 PCK → 统一加载资源)
 ├─ cues ──▶ GameplayCueManager (GodotGAS) + ModCueRegistrar
 └─ souls/monsters/vessels ──▶ CollectionDB (写 content_id) ──▶ SaveManager (缺失进 orphaned)
```

## 2. 启动时序与硬约束

1. `ModLoader._init()`：读 `user://mods.cfg`（启用态与 `[order]`），扫 `res://base_mods/*/mod.json` 与 `user://mods/*/mod.json`，校验/依赖排序后**先挂载全部 PCK，再统一加载内容**。
2. `GameGlobal`、`GBIS` 等按 `project.godot` 顺序启动。
3. `GameplayCueManager._ready()`（直接指向 `addons/GodotGAS/managers/gameplay_cue_manager.gd`，项目内 `cue_registry.tres` 为空）→ `ModCueRegistrar._ready()` 注册全部校验通过的 core 与 mod Cue。
4. `CollectionDB._ready()` 构建目录并写 `content_id` → `SaveManager` 等待容器就绪（不自动读档）→ 主场景启动。

**不可违反的约束**：
- PCK 必须在 `_init()` 挂载，且内容加载必须在全部 PCK 挂载后执行，否则先加载的资源进缓存导致覆盖失效。
- 无运行期卸载/重载 API，启停、改序与 Cue 变更均需重启生效；内置 mod 仅支持 loose 目录，不打包 `content.pck`。
- 禁止用路径式 `extends` 包装 addon 管理器（导出包会解析失败）；GodotGAS 内 `EditorInterface` 已改为 `Engine.get_singleton("EditorInterface")`，`remove_persistent_cue`/`set_cue_state` 允许已释放实例，升级 addon 时必须保留。

## 3. 内容校验、覆盖与冲突规则

- **单一规格表**：`ContentKind.Kind`（`SOUL/MONSTER/CUE/VESSEL`）与 `ContentKindSpec.all()` 由 `ModLoader`、`CoreContentValidator` 共用；新增内容种类只需改规格表 + 注册分支。
- **错误 vs 警告**：路径重复登记、语义校验失败（魂灵词表/尺寸标签、技能步骤/目标规则/执行器、怪物必填字段、越界路径）计入 `get_errors()` 且**拒绝注册**；未知 manifest 字段或技能 ID 冲突计入 `get_warnings()` 不阻止加载。
- **命名空间与覆盖**：`content_namespace: "global"` 与 `content_root` 仅限内置 mod，第三方填写直接拒绝；内容路径必须落在本 mod 根下，仅 `overrides` 允许声明覆盖其他 `res://` 路径（禁止覆盖 `project.godot`、`.godot/`、`base_mods/*/mod.json`、`Scripts/mod/`）。完整 ID/技能/Cue 命名表见 `指南/Mod制作.md` §2。
- **存档兼容**：存档只存 `content_id`，缺失内容进 `orphaned` 原样带回；版本号与迁移规则以 `架构/存档.md` §2/§5 为准（当前 `version: 2`）。

## 4. 管理窗口、加载顺序、安全与 Steam 规划

- **ModWindow**：`Windows/ModWindow/mod_window.gd` 纯脚本构建；内置 core 锁定启用且固定排序最前；勾选启停与上下移排序写 `user://mods.cfg`，重启生效。`dependencies` / `load_after` 优先级高于用户排序（`get_mod_order()` 返回用户顺序，`get_mod_load_order()` 返回实际加载顺序）。
- **安全边界**：PCK 可执行 GDScript 且 Godot 无沙箱，当前默认信任本地 mod；`overrides` 仅做声明级冲突检查，后续可解析 PCK 索引做白名单。
- **Steam 远期**：后续接入 GodotSteam `SteamService` + `WorkshopService`（订阅目录交给 `ModLoader`、对比时间戳提示重启、`steamcmd` 发布）。

## 5. 常见排查

1. **报错 / 内容数为 0**：查 `ModWindow` 逐条错误或 `ModLoader.get_errors()`；改完官方内容先跑 `EngineTools/modkit/validate_core_manifest.gd`。
2. **启用后内容未出现**：确认已重启游戏；核对第三方 ID 前缀（`<mod_id>:<local_id>`）与路径落在 `res://mods/<id>/content/`。
3. **读档进 `orphaned`**：勿手删 `orphaned`，重新启用对应 mod 后再读档会自动尝试放回。
4. **Cue 不播**：确认根节点继承 `GameplayCueNotify`、标签符合 `Cue.Mod.<PascalModId>.<Name>` 且已重启。
5. **加载顺序不生效**：确认已重启，并对比 `get_mod_order()` 与 `get_mod_load_order()` 检查是否被 `dependencies`/`load_after` 覆盖。
