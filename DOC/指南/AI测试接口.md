# AI 测试接口 TestAPI

> 类型：指南 | 状态：有效 | 核对：2026-11-11
> 何时读：写自动化测试/探针、构造战斗或背包场景、验证新功能
> 关键词：测试 TestAPI 探针 自动化 战斗快照 魂灵 仓库 见闻 商店 冷却 冻结 触发器 类型 标签 充能 卡面 tooltip 伤害缩放 多重触发 cast_times releases 颜色 色板 存档 save 爪痕 play_claw_cue mod ModLoader ModWindow 加载顺序 order mod_cue_registrar cue Cue 特效 manifest 创意工坊 内置 core content_id validate_core_manifest manifest 校验 技能 ID ability_tag 命名 窗口置顶 T Settings.cfg window_id
> 代码：`Scripts/test_api.gd`、`Windows/Battle/battle_window.gd`、`Scripts/collection_db.gd`、`Scripts/save/`、`Scripts/mod/`、`base_mods/core/mod.json`
> 约定：新增功能/内容时，同步补 TestAPI 方法并更新本文。

## 用法

`TestAPI` 是全局静态类，不用挂节点。探针场景里直接调用：

```gdscript
TestAPI.set_unlock_all(false)
TestAPI.clear_container("inventory_0")
TestAPI.add_soul(&"xiao_lu_soul")
TestAPI.equip_soul(&"xiao_lu_soul")
TestAPI.start_battle(&"snake_monster")
await get_tree().physics_frame
var state := TestAPI.get_battle_state()
print(state)
TestAPI.stop_battle()
```

魂灵/怪物 ID 用 `TestAPI.get_soul_ids()`、`TestAPI.get_monster_ids()` 查，必须是 `content_id`（core 如 `snake_monster`、`fu_monster`；第三方带 `<mod_id>:` 前缀）。技能标签用 `TestAPI.get_skill_tags()` 查，core 如 `Skill.XiaoLu`，第三方如 `Skill.Mod.ExampleSouls.FireWolf`。

## 背包 / 见闻

| 方法 | 说明 |
|---|---|
| `add_soul(id, container := "") -> bool` | 按 content_id 放入指定容器；`container` 为空时放仓库第 1 页 |
| `add_soul_to_warehouse(id) -> bool` | 按 content_id 放入仓库，从第 1 页开始找空位 |
| `show_shop() -> bool` | 显示商店窗口；找不到窗口返回 `false` |
| `shop_add_soul(id) -> bool` | 按 content_id 往 `shop_0` 追加一颗魂灵；清空用 `clear_container("shop_0")` |
| `pick_up_item(container, grid_id) -> bool` | 模拟左键从格子拿起物品，进入拖拽状态 |
| `drop_moving_item(container, grid_id) -> bool` | 把正在拖拽的物品放到指定格子；`grid_id` 是鼠标点击格，物品左上角 = `grid_id` - 抓取偏移 |
| `sell_moving_item() -> bool` | 在商店出售正在拖拽的物品 |
| `cancel_moving_item() -> bool` | 模拟右键取消拿起；优先放回原格 |
| `quick_sell(container, grid_id) -> bool` | 直接出售格子里的物品；商店和该容器都打开才生效 |
| `set_warehouse_page(page) -> bool` | 切换仓库窗口到指定页（0 起）；窗口不存在返回 `false` |
| `get_warehouse_page() -> int` | 当前仓库页码（0 起）；找不到窗口返回 `-1` |
| `equip_soul(id, part := "") -> bool` | 放入 `cell_0..3`；`part` 为空时按魂灵部位，ANY 依次尝试四个部位 |
| `clear_container(container) -> void` | 清空容器并刷新 |
| `get_container_items(container) -> Array[String]` | 容器内物品名 |
| `validate_container_ids() -> Array[String]` | 校验 `ContainerIds` 里的仓库、商店、魂灵格是否都已注册；主场景运行后调用 |
| `set_unlock_all(enabled) -> void` | 切换见闻全解锁（不写存档） |
| `get_seen_ids(kind) -> Array[StringName]` | 真实已解锁 ID |
| `is_seen(kind, id) -> bool` | 单个条目是否解锁 |
| `get_soul_ids()` / `get_monster_ids()` | 列出内容条目（core + 第三方 mod） |
| `get_rare_monster_ids() -> Array[StringName]` | 标记为 `is_rare` 的怪物 content_id |
| `get_soul_types(id) -> Array[StringName]` | 魂灵类型，如 `Soul.types.Wolf`、`Soul.types.Animal` |
| `get_soul_tags(id) -> Array[StringName]` | 魂灵见闻标签，如 `Soul.tags.Small`、`Soul.tags.Burn` |
| `get_skill_tags() -> Array[Dictionary]` | 所有魂灵的 `content_id`、技能 ID 和 `ability_tag`，用于核对技能命名规范 |
| `get_soul_card_info(id) -> Dictionary` | 魂灵卡面：`icon` 路径、`columns`/`rows`、`label` 名称文本 |
| `get_soul_damage_scaling(id) -> Dictionary` | 从所有 `UnitSkillStep` 里找第一个直接伤害的 `base_damage` / `bonus_per_matching_soul` / `matching_soul_types` |
| `get_soul_steps(id) -> Array[Dictionary]` | 技能步骤：`index` / `type` / `domain` / `target_rule` / 效果数量 / `status_magnitude` / 状态时长 |
| `get_soul_cast_times(id) -> int` | 魂灵技能的多重触发次数；未知魂灵或无技能返回 `0` |
| `get_soul_tooltip_text(id) -> String` | 魂灵 tooltip 完整纯文本；第一行是标题，后面是正文（格式见 `魂灵/魂灵.md`） |
| `get_soul_tooltip_bbcode(id) -> String` | 魂灵 tooltip 的 BBCode 文本；正文状态词带颜色标签，用于验证上色 |

`kind` 用 `ContentKind.Kind.SOUL` / `ContentKind.Kind.MONSTER`。见闻窗口的魂灵条目悬停使用与仓库相同的 tooltip（标题是 `item_name`，正文由 `SoulTooltip.build(soul, true)` 生成）；右键已遇见魂灵等价于 `add_soul_to_warehouse(id)`。

仓库有 10 页（`inventory_0..inventory_9`）。测试时用 `add_soul_to_warehouse()` 自动入页，或 `set_warehouse_page()` 切到指定页观察显示；页码从 0 开始。

拖拽取消可以这样验证：

```gdscript
TestAPI.clear_container("inventory_0")
TestAPI.add_soul(&"xiao_lu_soul")          # 落在 (0, 0)
TestAPI.pick_up_item("inventory_0", Vector2i.ZERO)
TestAPI.cancel_moving_item()               # 物品回到 (0, 0)

TestAPI.pick_up_item("inventory_0", Vector2i.ZERO)
TestAPI.drop_moving_item("inventory_0", Vector2i(5, 0))  # 放到指定格
```

## 存档

| 方法 | 说明 |
|---|---|
| `save_now() -> bool` | 立即写档到 `user://saves/slot_0.json` |
| `load_save() -> bool` | 从磁盘读档，清空并按精确格子重建所有容器；不要在战斗/拖拽中调用 |
| `delete_save() -> bool` | 只删除磁盘存档，不改变当前内存状态；要回到新游戏再调用 `load_save()` |
| `has_save() -> bool` | 是否存在主文件或备份 |
| `get_save_path() -> String` | 返回 `user://saves/slot_0.json`；绝对路径用 `ProjectSettings.globalize_path()` |
| `get_save_status() -> Dictionary` | `ready` / `read_only` / `missing_containers`；缺容器时只读，不读也不写 |
| `dump_save() -> Dictionary` | 当前内存状态的存档快照，不写盘；用于检查序列化结果 |

```gdscript
TestAPI.clear_container("inventory_0")
TestAPI.add_soul(&"xiao_lu_soul")
TestAPI.save_now()
print(TestAPI.get_save_path())
TestAPI.clear_container("inventory_0")
TestAPI.load_save()
print(TestAPI.get_container_items("inventory_0"))
TestAPI.delete_save()
```

读档会保留物品的左上角格子，所以验证装备栏相邻关系时可以直接比较读档前后的锚点。存档结构、备份/迁移规则见 `架构/存档.md`。

## Mod

| 方法 | 说明 |
|---|---|
| `get_mod_list() -> Array[Dictionary]` | 已发现 mod 的概况：`id`、`name`、`version`、`author`、`description`、`source`（`builtin`/`local`）、`builtin`、`locked`、`enabled`、`blocked`、`loaded`、`mounted`、`load_index`、内容数量、错误和警告 |
| `get_mod_errors() -> Array[String]` | `ModLoader` 的错误汇总；加载失败/ID 冲突/依赖缺失/Cue 注册失败都看这里 |
| `get_mod_warnings() -> Array[String]` | 不阻止加载的诊断：未知 manifest 字段、技能 ID 冲突等 |
| `is_builtin_mod(id) -> bool` | 某个 mod 是否为内置 mod（core） |
| `get_mod_content_ids(id) -> Dictionary` | 某个 mod 注册的 `souls` / `monsters` / `cues` ID 列表 |
| `validate_core_manifest() -> Array[String]` | 校验 `base_mods/core/mod.json` 与 `souls/`、`monsters/`、`cues/` 文件是否一一对应；空数组表示通过 |
| `get_mod_cues() -> Array[Dictionary]` | Cue 的 `tag`、`mod`、`path`、`registered`；包含 core 和第三方 |
| `is_mod_cue_registered(tag) -> bool` | 某个 mod Cue 标签是否已注册到 `GameplayCueManager` |
| `show_mod_window() -> bool` | 打开 Mod 管理窗口并刷新 |
| `get_mod_window_state() -> Dictionary` | 窗口状态：`visible`、`mods`、`loaded`、`pending`、`order_pending`、`order`、`load_order`、`errors`、`summary` |
| `get_mod_load_order() -> Array[StringName]` | 本次实际加载顺序（只含已启用且未被阻止的 mod） |
| `get_mod_order() -> Array[StringName]` | 用户指定的基础加载顺序；内置 mod 固定在最前 |
| `set_mod_order(ids) -> bool` | 写 `user://mods.cfg` 的 `[order]`；内置 mod 会被强制归位到最前，运行期不重排，重启后生效 |
| `set_mod_enabled(id, enabled) -> bool` | 写 `user://mods.cfg`；内置 mod 返回 false，当前运行期不会卸载/重载，重启后生效 |
| `get_orphaned_records() -> Array[Dictionary]` | 当前存档里因 mod 缺失/容器满而保留的原始记录 |

```gdscript
print(TestAPI.get_mod_list())
print(TestAPI.get_mod_errors())
print(TestAPI.get_mod_warnings())
print(TestAPI.is_builtin_mod(&"core"))
print(TestAPI.get_mod_content_ids(&"core"))  # souls 19 / monsters 2 / cues 5
print(TestAPI.validate_core_manifest())
print(TestAPI.get_mod_cues())
print(TestAPI.is_mod_cue_registered(&"Cue.Status.Burn"))
print(TestAPI.is_mod_cue_registered(&"Cue.Mod.ExampleSouls.Fire"))
print(TestAPI.show_mod_window())
print(TestAPI.get_mod_window_state())
print(TestAPI.get_mod_order())
print(TestAPI.get_mod_load_order())
```

- 内置 core 清单在 `base_mods/core/mod.json`，固定启用、排序最前；第三方 mod 目录是 `user://mods/<mod_id>/`，最小结构 `mod.json` + `content.pck`，开发期可以只放 loose 目录。
- 制作和字段说明见 `指南/Mod制作.md`，加载规则见 `架构/Mod系统.md`。core 内容 ID 沿用原值（`xiao_lu_soul`、`fu_monster`），第三方内容 ID 带 `<mod_id>:` 前缀，都可以直接传给 `add_soul()` / `get_soul_ids()`。
- 装好示例 mod 后，可以用 `TestAPI.add_soul_to_warehouse(&"example_souls:fire_wolf_soul")` 验证。示例源码在 `mods/example_souls/`，打包脚本是 `modkit/pack_example.gd`。

## 窗口

| 方法 | 说明 |
|---|---|
| `set_window_pinned(window_name, pinned) -> bool` | 设置窗口置顶；`window_name` 为节点名（`CharacterWindow`、`InventoryWindow` 等），主窗口用 `MainWindow`；写入 `user://Settings.cfg`，键是稳定 `window_id`（默认脚本文件名，主窗口 `main_window`） |
| `is_window_pinned(window_name) -> bool` | 查询窗口置顶状态 |
| `get_window_pin_states() -> Dictionary` | 所有普通窗口的置顶状态：`{节点名: bool}`，含 `MainWindow` |

```gdscript
print(TestAPI.set_window_pinned("CharacterWindow", true))
print(TestAPI.is_window_pinned("CharacterWindow"))
print(TestAPI.get_window_pin_states())
```

窗口置顶状态存在 `user://Settings.cfg` 的 `[window_pins]` 段。键是 `BaseWindow.get_pin_key()`（默认脚本文件名，如 `character_window`）或 `main_window`，与节点名解耦。`TooltipWindow` / `ItemWindow` 没有置顶接口，固定 transient 跟随主窗口。

## 颜色

| 方法 | 说明 |
|---|---|
| `get_game_color(name) -> String` | 按常量名取 `GameColors` 的十六进制色值，如 `"DAMAGE"`、`"TEXT_PRIMARY"`；`Color` 常量会转成 HTML 色值 |

## 战斗

| 方法 | 说明 |
|---|---|
| `start_battle(monster_id := &"") -> bool` | 显示战斗窗口并开战；首只必刷指定怪 |
| `stop_battle() -> void` | 结束当前战斗 |
| `spawn_monster(monster_id) -> bool` | 在远处空位刷一只指定怪 |
| `apply_burn(target := "player") -> bool` | 对战斗单位施加灼烧（测试状态与火焰 Cue） |
| `apply_poison(target := "player") -> bool` | 对战斗单位施加剧毒（测试飞溅与气泡 Cue） |
| `apply_regen(target := "player") -> bool` | 对战斗单位施加生命再生（测试剧毒/再生相减） |
| `apply_freeze(target := "player", seconds := 3.0) -> bool` | 对战斗单位施加冻结（测试冻结 Cue 与 `State.Frozen`）；会广播 `Event.Combat.FreezeApplied` |
| `play_claw_cue(target := "enemy", direction := 1) -> bool` | 在单位身上播放恐狼爪痕 Cue；`direction` 1 = 左→右，-1 = 右→左 |
| `apply_soul_freeze(soul_name, seconds := 1.0, target := "player") -> bool` | 对已装备的指定魂灵施加魂灵级冻结（测试冰霜 shader 与徽章） |
| `simulate_soul_used(soul_name, target := "player") -> bool` | 模拟“魂灵被使用”（不动冷却），确定性验证 `Event.Combat.SoulUsed` 触发器；触发充能满时会走同帧待释放队列，调用后等一帧再读状态 |
| `charge_soul(soul_name, seconds, target := "player") -> bool` | 给已装备魂灵直接充能，用于快速触发主动技能；不经过触发器队列 |
| `damage_unit(target := "player", amount := 1.0) -> bool` | 对单位造成伤害，用于把生命值打到阈值以下（测半血触发） |
| `has_status(tag, target := "player") -> bool` | 单位是否拥有某个状态标签 |
| `get_battle_state() -> Dictionary` | 战斗快照；含刷怪进度 `normal_kills` / `pending_rare_spawns` |
| `get_enemy_count() -> int` | 当前存活敌人数 |
| `get_nearest_enemy_distance() -> float` | 最近敌人到角色的像素距离；没有敌人返回 -1 |
| `get_enemies_in_attack_range() -> int` | 当前在角色攻击范围内的敌人数（即时制下只有这些怪才充能） |
| `get_perf_snapshot() -> Dictionary` | 性能快照：FPS、节点数、敌人数、范围内敌人数、最近距离 |
| `get_battle_log() -> String` | 当前战斗日志纯文本 |
| `get_fps_text() -> String` | 战斗窗口右上角的 FPS 文本 |

`target` 支持 `"player"`、`"enemy"` 或单位名。灼烧测试可用：

```gdscript
TestAPI.apply_burn("player")
print(TestAPI.has_status(&"State.Burning", "player"))

TestAPI.apply_poison("enemy")
print(TestAPI.has_status(&"State.Poisoned", "enemy"))

# 剧毒/再生直接相减：毒 8、再生 5 时每秒净扣 3 点生命
TestAPI.apply_regen("enemy")
await get_tree().create_timer(1.3).timeout
print(TestAPI.get_battle_state()["enemies"][0]["hp"])

TestAPI.apply_freeze("enemy", 3.0)
print(TestAPI.has_status(&"State.Frozen", "enemy"))
TestAPI.apply_soul_freeze("尖牙", 1.0)

# 爪痕：分别看左右两个方向
TestAPI.play_claw_cue("enemy", 1)
await get_tree().create_timer(0.2).timeout
TestAPI.play_claw_cue("enemy", -1)

# 半血触发：把玩家打到阈值以下，再检查触发器效果
TestAPI.damage_unit("player", 300.0)
print(TestAPI.has_status(&"State.Frozen", "enemy"))

# 恐狼：每有一颗 Soul.types.Wolf +10 伤害；1 颗 = 40，2 颗 = 50
TestAPI.clear_container("cell_2")
TestAPI.equip_soul(&"kong_lang_soul", "ARMSSOUL")
print(TestAPI.get_soul_damage_scaling(&"kong_lang_soul"))
TestAPI.equip_soul(&"kong_lang_soul", "ARMSSOUL")
print(TestAPI.get_soul_damage_scaling(&"kong_lang_soul"))

# 恐狼：直接充能触发主动技能
TestAPI.start_battle(&"snake_monster")
TestAPI.charge_soul("恐狼", 5.0)
await get_tree().physics_frame
print(TestAPI.get_battle_state()["player_souls"])

# 模拟“魂灵被使用”事件；当前没有魂灵配置 SoulUsed 触发器，接口保留
TestAPI.simulate_soul_used("恐狼")
print(TestAPI.get_battle_state()["player_souls"])
```

快照结构：

```gdscript
{
  "running": true,
  "elapsed": 12.3,
  "player": {"name", "hp", "max_hp", "shield", "regen", "poison", "dead", "frozen",
             "cell", "position", "distance_to_player", "in_attack_range", "souls"},
  "enemies": [{"name", "hp", "max_hp", "shield", "regen", "poison", "dead", "frozen",
               "cell", "position", "distance_to_player", "in_attack_range", "souls"}],
  "player_souls": [{"name", "cooldown", "charge_ratio", "charge_seconds", "haste", "slow",
                    "freeze", "frozen", "active", "activation_lock"}],
  "normal_kills": 3,
  "pending_rare_spawns": 0
}
```

`player_souls[].freeze` 是魂灵级冻结剩余秒数；`frozen` 是 `is_frozen()`（自身冻结或单位冻结）。单位的 `frozen` 只表示 `State.Frozen` 标签。`charge_seconds` 用于精确验证充能触发（例如相邻魂灵被使用后 +1 秒）。`active` 是技能是否还在执行中（投射物发射后不再占用它）；`activation_lock` 是 20 刻激活锁的剩余秒数，用于验证 1 秒最多 6 次的限制。

即时制下 `cell` 只是“当前压在地图哪一格”，真实位置看 `position`（像素）；`distance_to_player` 和 `in_attack_range` 用来验证“进范围才充能”。

## 调试 / 遥测

| 方法 | 说明 |
|---|---|
| `get_debug_events(category := "", limit := 200) -> Array` | 最近调试事件；`category` 见 `CombatEvent`（`battle`/`cast`/`soul`/`trigger`/`effect`/`attribute`/`tag`/`cue`/`log`/`system`） |
| `get_debug_stats() -> Dictionary` | 缓冲大小、丢失数、场次、关注单位、文件录制状态 |
| `get_debug_snapshot() -> Dictionary` | 当前战斗快照（玩家完整详情、敌人摘要） |
| `get_soul_runtime(soul_name, target := "player") -> Dictionary` | 某颗已装备魂灵的运行期状态（冷却/充能/状态/统计/触发器） |
| `get_trigger_state(soul_name, target := "player") -> Array` | 某颗魂灵的触发器列表与 `fired` 状态 |
| `clear_debug_events() -> void` | 清空事件缓冲 |
| `export_debug_log(path := "user://debug/test.jsonl") -> String` | 导出 JSONL，返回绝对路径 |
| `set_debug_recording(enabled) -> void` | 开关遥测；关闭后 `record()` 直接返回 |
| `watch_unit_for_debug(target := "player") -> bool` | 设置关注单位，详细事件只记录它 |

事件里带 `trace_id / parent_trace_id / root_trace_id`，可用 `CombatTelemetry.get_trace_chain(trace_id)` 还原因果链。

## 注意

- 只用于测试/探针；会改运行时状态。
- `set_unlock_all(false)` 后，`add_soul` 仍会走正常入包流程，并打上存档脏标记，由 `SaveManager` 写入 `user://saves/slot_0.json`。
- `set_unlock_all` 只改判定，不会自动刷新已打开的见闻窗口；切页签或重开窗口即可。
- `player.souls` 是场景配置（玩家通常为空）；玩家装备的魂灵看 `player_souls`。
- `start_battle` 会显示战斗窗口；找不到 `BattleWindow` 时返回 `false`。
- 游戏已移除倍速功能，`TestAPI` 不再提供 `set_time_scale`；需要验证长流程时用真实时间等待或多跑几帧。
- 新增全局类后，如果 headless 直接跑提示 `TestAPI` 未声明，先用编辑器打开一次项目（或 `--headless --editor --quit`）刷新全局类缓存。
- 新增魂灵/怪物/技能/窗口时，先看这里要不要补方法。
