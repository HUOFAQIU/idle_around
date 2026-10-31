# AI 测试接口 TestAPI

> 类型：指南 | 状态：有效 | 核对：2026-10-31
> 何时读：写自动化测试/探针、构造战斗或背包场景、验证新功能
> 关键词：测试 TestAPI 探针 自动化 战斗快照 魂灵 仓库 见闻 冷却
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

`kind` 用 `CollectionDB.Kind.SOUL` / `CollectionDB.Kind.MONSTER`。

## 战斗

| 方法 | 说明 |
|---|---|
| `start_battle(monster_id := &"") -> bool` | 显示战斗窗口并开战；首只必刷指定怪 |
| `stop_battle() -> void` | 结束战斗并还原时间倍率 |
| `spawn_monster(monster_id) -> bool` | 在远处空位刷一只指定怪 |
| `apply_burn(target := "player") -> bool` | 对战斗单位施加灼烧（测试状态与火焰 Cue） |
| `has_status(tag, target := "player") -> bool` | 单位是否拥有某个状态标签 |
| `get_battle_state() -> Dictionary` | 战斗快照 |
| `set_time_scale(scale) -> void` | 全局时间倍率，范围 0.1～20 |
| `get_battle_log() -> String` | 当前战斗日志纯文本 |
| `get_fps_text() -> String` | 战斗窗口右上角的 FPS 文本 |

`target` 支持 `"player"`、`"enemy"` 或单位名。灼烧测试可用：

```gdscript
TestAPI.apply_burn("player")
print(TestAPI.has_status(&"State.Burning", "player"))
```

快照结构：

```gdscript
{
  "running": true,
  "elapsed": 12.3,
  "time_scale": 1.0,
  "player": {"name", "hp", "max_hp", "shield", "dead", "cell", "souls"},
  "enemies": [{"name", "hp", "max_hp", "shield", "dead", "cell", "souls"}],
  "player_souls": [{"name", "cooldown", "charge_ratio", "haste", "slow", "frozen"}]
}
```

## 注意

- 只用于测试/探针；会改运行时状态。
- `set_unlock_all(false)` 后，`add_soul` 仍会走正常入包流程并写入 `user://collection.cfg`。
- `set_unlock_all` 只改判定，不会自动刷新已打开的见闻窗口；切页签或重开窗口即可。
- `player.souls` 是场景配置（玩家通常为空）；玩家装备的魂灵看 `player_souls`。
- `start_battle` 会显示战斗窗口；找不到 `BattleWindow` 时返回 `false`。
- `stop_battle` 会把 `Engine.time_scale` 还原为 1。
- 新增全局类后，如果 headless 直接跑提示 `TestAPI` 未声明，先用编辑器打开一次项目（或 `--headless --editor --quit`）刷新全局类缓存。
- 新增魂灵/怪物/技能/窗口时，先看这里要不要补方法。
