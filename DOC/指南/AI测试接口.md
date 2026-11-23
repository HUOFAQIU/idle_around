# AI 测试接口 TestAPI

> 类型：指南 | 状态：有效 | 核对：2026-11-22
> 何时读：写自动化测试/探针、构造战斗或背包场景、验证新功能
> 关键词：测试 TestAPI 探针 自动化 战斗快照 存档 地图 Mod 窗口 终端 tooltip 颜色 遥测
> 代码：`Scripts/test_api.gd`（门面）、`Scripts/test_api/`（按域实现）、`Scripts/commands/`
> 相关：`指南/代码检查.md`、`指南/命令控制台.md`
> 不覆盖：逐方法清单看域模块；命令语法见 `指南/命令控制台.md`
> 约定：新增测试方法在域模块实现并在门面转发；只有新增域或入口语义变化时才更新本文。

## 用法

`TestAPI` 是全局静态类，探针场景里直接调用：

```gdscript
TestAPI.new_game()
TestAPI.clear_container("inventory_0")
TestAPI.add_soul(TestAPI.get_soul_ids()[0])
TestAPI.equip_vessel(TestAPI.get_vessel_ids()[0])
TestAPI.start_battle()
await get_tree().physics_frame
print(TestAPI.get_battle_state())
TestAPI.stop_battle()
```

调用入口始终是 `TestAPI`。实现按域放在 `Scripts/test_api/`，`Scripts/test_api.gd` 只做一行转发；找方法直接 grep 这两个位置。

- content_id：core 不带前缀，第三方带 `<mod_id>:`。`get_soul_ids()` / `get_monster_ids()` / `get_vessel_ids()` 列出当前已加载的条目。
- 技能标签 `get_skill_tags()`：core 形如 `Skill.<PascalName>`，第三方形如 `Skill.Mod.<PascalModId>.<PascalName>`。
- 文本命令与终端共用 `CommandRegistry.run(line)`（返回 `{ok, value, error}`）和 `CommandRegistry.complete(line, caret)`；handler 调同一批域模块。

## 域模块

| 域 | 文件 | 覆盖 |
|---|---|---|
| 背包/魂器/见闻 | `Scripts/test_api/inventory.gd` | 容器、拖拽、魂器网格、见闻解锁、tooltip 文本 |
| 魂灵情绪 | `soul.gd` | 情绪表、范围、有效情绪、按稀有度 roll、指定构成、tooltip、存档往返 |
| 地图 | `map.gd` | 地图板入槽/排队/退回、数量石 |
| 存档 | `save.gd` | 新游戏、读档、删档、槽位、管线自检 |
| Mod | `mod.gd` | 列表、加载顺序、内容 ID、Cue、管理窗口 |
| 窗口 | `window.gd` | 主窗口置顶、面板矩形、穿透开关 |
| 立方体 | `cube.gd` | 层级、面内容、面锁定、面按钮点击 |
| 颜色 | `colors.gd` | 取色、色板目录、分组校验 |
| 终端 | `terminal.gd` | 写入、滚动、快照、命令补全、tooltip 上屏 |
| 战斗 | `battle.gd` | 开战、刷怪、状态、冻结、减速、迅捷/迟缓、移速查询、移动、充能、快照、时钟 |
| 调试 | `debug.gd` | 事件、统计、触发状态、JSONL 导出 |
| 通用 | `common.gd` | 容器名、物品名等跨域查询 |

## 非显然语义

- `add_soul(id, container := "")`：容器为空时从仓库第 1 页开始找空位；容器不存在返回 `false`；`add_vessel` 同理。
- `load_save_slot(slot)` 走完整切档流程（保存当前槽、结束战斗、关面板、读目标槽、锁 04/解锁 02、翻到 02 面）；`load_save_slot_direct(slot)` 直调 `SaveManager.load_slot()`，不改 `GameFlow` 状态和立方体朝向，只给存档格式/迁移测试用。
- 启动不自动读档：先 `new_game()` 或 `load_save_slot()` 才有活动槽，否则 `save_now()` 返回 false。
- `check_save_pipeline()` 用内存 storage + fake participant 跑完整管线，不碰真实存档，启动后可直接调用。
- `delete_save_slot()` 是绕过 UI 的后端直删；游戏内删除走 `click_cube_delete_save_slot()`（两次确认，活动槽不可删）。
- `get_battle_state()` 是战斗快照的唯一生产者（直读 `game/battle/battle_session.gd::get_state()`）；`get_perf_snapshot()` 只出性能数字。
- 战斗窗口不能空开，`start_battle()` 必须带地图；游戏没有倍速，确定性验证长流程用 `pause_battle()` + `step_battle()`（GAS 持续效果也一起走）。
- `player.souls` 是场景配置（通常为空）；实际装备看 `player_souls`。`player_souls[].freeze` 是魂灵级冻结剩余秒数，`frozen` 是 `is_frozen()`。
- `*_text` / `*_bbcode` / `*_ansi` 是同一份 tooltip 内容的三种格式；`get_equipped_soul_damage_preview()` 战斗中优先运行期值，未开战时按当前魂器网格静态预览。
- `set_unlock_all()` 只改判定、不写存档、不刷新已打开的见闻窗口；`add_soul()` 仍走正常入包并打存档脏标记。
- 状态类方法的 `target` 参数接受 `"player"` / `"enemy"` / 单位名；单位名查到多个时跳过已死亡与所在战斗已排队销毁的旧节点，取当前战斗里的那个。
- `get_move_speed(target)` 返回 `move_speed` 属性当前值（含迅捷/迟缓修饰），默认目标 `"enemy"`；`apply_swift()` / `apply_sluggish()` 是单位级移动状态，默认目标同为 `"enemy"`，与魂灵级 `apply_soul_slow()` 不同。
- `roll_soul_emotions(id, rarity, rng_seed)` / `apply_soul_emotions(id, emotions)` 返回实例快照：`emotions`、`values`、`damage`、`cooldown`、`cast_times`；魂灵未声明该参数时伤害/冷却为 -1、多重触发为 0，声明了但构成里没有时按占比 0 取左端。
- `roll_soul_to_warehouse(id, rarity, rng_seed)` 生成带构成的实例并写入仓库，返回同一份实例快照；`rng_seed < 0` 时随机，`soul.roll` 命令走它。
- `check_soul_emotion_roundtrip()` 复用存档编解码，返回 `{ok, checks}`；与 `check_save_pipeline()` 一样不碰真实存档。

## 注意

- 只用于测试/探针，会改运行时状态。
- 无头测试把 `APPDATA` 指到临时目录，避免写真实 `user://`；新增全局类后先 `--headless --path . --import` 刷新类缓存。
- 存档结构见 `架构/存档.md`，开局状态机见 `架构/开局流程.md`，战斗时序见 `架构/战斗运行时_施法与冷却.md`。
