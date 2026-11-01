# AI 测试接口 TestAPI

> 类型：指南 | 状态：有效 | 核对：2026-11-01
> 何时读：写自动化测试/探针、构造战斗或背包场景、验证新功能
> 关键词：测试 TestAPI 探针 自动化 战斗快照 魂灵 仓库 见闻 冷却 冻结 触发器 标签 充能
> 代码：`Scripts/test_api.gd`、`Windows/Battle/battle_window.gd`、`Scripts/collection_db.gd`
> 约定：新增功能/内容时，同步补 TestAPI 方法并更新本文。

## 用法

`TestAPI` 是全局静态类，不用挂节点。探针场景里直接调用：

```gdscript
TestAPI.set_unlock_all(false)
TestAPI.clear_container("inventory_0")
TestAPI.add_soul(&"xiao_lu_soul")
TestAPI.equip_soul(&"xiao_lu_soul")
TestAPI.start_battle(&"snake_data")
await get_tree().physics_frame
var state := TestAPI.get_battle_state()
print(state)
TestAPI.stop_battle()
```

魂灵/怪物 ID 用 `TestAPI.get_soul_ids()`、`TestAPI.get_monster_ids()` 查，必须是 registry 里的字符串 ID（个别资源带 `_2` 后缀）。

## 背包 / 见闻

| 方法 | 说明 |
|---|---|
| `add_soul(id, container := "inventory_0") -> bool` | 按 registry ID 放入魂灵 |
| `equip_soul(id, part := "") -> bool` | 放入 `cell_0..3`；`part` 为空时按魂灵部位，ANY 依次尝试四个部位 |
| `clear_container(container) -> void` | 清空容器并刷新 |
| `get_container_items(container) -> Array[String]` | 容器内物品名 |
| `set_unlock_all(enabled) -> void` | 切换见闻全解锁（不写存档） |
| `get_seen_ids(kind) -> Array[StringName]` | 真实已解锁 ID |
| `is_seen(kind, id) -> bool` | 单个条目是否解锁 |
| `get_soul_ids()` / `get_monster_ids()` | 列出 registry 条目 |
| `get_soul_tags(id) -> Array[StringName]` | 魂灵标签，如 `Soul.Medium`、`Soul.RealEstate` |

`kind` 用 `CollectionDB.Kind.SOUL` / `CollectionDB.Kind.MONSTER`。

## 战斗

| 方法 | 说明 |
|---|---|
| `start_battle(monster_id := &"") -> bool` | 显示战斗窗口并开战；首只必刷指定怪 |
| `stop_battle() -> void` | 结束战斗并还原时间倍率 |
| `spawn_monster(monster_id) -> bool` | 在远处空位刷一只指定怪 |
| `apply_burn(target := "player") -> bool` | 对战斗单位施加灼烧（测试状态与火焰 Cue） |
| `apply_poison(target := "player") -> bool` | 对战斗单位施加剧毒（测试飞溅与气泡 Cue） |
| `apply_regen(target := "player") -> bool` | 对战斗单位施加生命再生（测试剧毒/再生相减） |
| `apply_freeze(target := "player", seconds := 3.0) -> bool` | 对战斗单位施加冻结（测试冻结 Cue 与 `State.Frozen`）；会广播 `FREEZE_APPLIED` |
| `apply_soul_freeze(soul_name, seconds := 1.0, target := "player") -> bool` | 对已装备的指定魂灵施加魂灵级冻结（测试冰霜 shader 与徽章） |
| `simulate_soul_used(soul_name, target := "player") -> bool` | 模拟“魂灵被使用”（不动冷却），确定性验证 `OTHER_SOUL_USED` 触发器 |
| `charge_soul(soul_name, seconds, target := "player") -> bool` | 给已装备魂灵直接充能，用于快速触发主动技能 |
| `damage_unit(target := "player", amount := 1.0) -> bool` | 对单位造成伤害，用于把生命值打到阈值以下（测温泉半血触发） |
| `has_status(tag, target := "player") -> bool` | 单位是否拥有某个状态标签 |
| `get_battle_state() -> Dictionary` | 战斗快照 |
| `get_enemy_count() -> int` | 当前存活敌人数 |
| `get_nearest_enemy_distance() -> float` | 最近敌人到角色的像素距离；没有敌人返回 -1 |
| `get_enemies_in_attack_range() -> int` | 当前在角色攻击范围内的敌人数（即时制下只有这些怪才充能） |
| `get_perf_snapshot() -> Dictionary` | 性能快照：FPS、节点数、敌人数、范围内敌人数、最近距离 |
| `set_time_scale(scale) -> void` | 全局时间倍率，范围 0.1～20 |
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

# 温泉：把玩家打到半血以下，触发全体冻结；每有一只怪物被冻结，温泉额外充能 3 秒
TestAPI.damage_unit("player", 300.0)
print(TestAPI.has_status(&"State.Frozen", "enemy"))

# 冷冻间：同栏再放一颗相邻的地产魂灵（温泉），模拟被使用时应给冷冻间 +1 秒
TestAPI.equip_soul(&"leng_dong_jian_soul")
GBIS.add_item("cell_0", CollectionDB.get_soul(&"wen_quan_soul"))
TestAPI.start_battle(&"snake_data")
TestAPI.charge_soul("冷冻间", 5.0)
await get_tree().physics_frame
print(TestAPI.get_battle_state()["player"]["regen"])

TestAPI.simulate_soul_used("温泉")
print(TestAPI.get_battle_state()["player_souls"])
```

快照结构：

```gdscript
{
  "running": true,
  "elapsed": 12.3,
  "time_scale": 1.0,
  "player": {"name", "hp", "max_hp", "shield", "regen", "poison", "dead", "frozen",
             "cell", "position", "distance_to_player", "in_attack_range", "souls"},
  "enemies": [{"name", "hp", "max_hp", "shield", "regen", "poison", "dead", "frozen",
               "cell", "position", "distance_to_player", "in_attack_range", "souls"}],
  "player_souls": [{"name", "cooldown", "charge_ratio", "charge_seconds", "haste", "slow", "freeze", "frozen"}]
}
```

`player_souls[].freeze` 是魂灵级冻结剩余秒数；`frozen` 是 `is_frozen()`（自身冻结或单位冻结）。单位的 `frozen` 只表示 `State.Frozen` 标签。`charge_seconds` 用于精确验证充能触发（例如相邻地产魂灵被使用后 +1 秒）。

即时制下 `cell` 只是“当前压在地图哪一格”，真实位置看 `position`（像素）；`distance_to_player` 和 `in_attack_range` 用来验证“进范围才充能”。

## 注意

- 只用于测试/探针；会改运行时状态。
- `set_unlock_all(false)` 后，`add_soul` 仍会走正常入包流程并写入 `user://collection.cfg`。
- `set_unlock_all` 只改判定，不会自动刷新已打开的见闻窗口；切页签或重开窗口即可。
- `player.souls` 是场景配置（玩家通常为空）；玩家装备的魂灵看 `player_souls`。
- `start_battle` 会显示战斗窗口；找不到 `BattleWindow` 时返回 `false`。
- `stop_battle` 会把 `Engine.time_scale` 还原为 1。
- 高倍速下控制台战斗日志每秒最多 20 条；`get_battle_log()` 读的是战斗窗口里的完整日志，不受影响。
- 新增全局类后，如果 headless 直接跑提示 `TestAPI` 未声明，先用编辑器打开一次项目（或 `--headless --editor --quit`）刷新全局类缓存。
- 新增魂灵/怪物/技能/窗口时，先看这里要不要补方法。
