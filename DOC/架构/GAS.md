# GAS 适配层

> 类型：实现 | 状态：有效 | 核对：2026-10-28
> 何时读：改属性集、标签注册、Cue 注册
> 关键词：GAS GameplayAbility AttributeSet Tag Cue godot_gas
> 代码：godot_gas/
> 相关：`特效/effects.md`
>
> 旧版架构长文第 6 节。

## 6. GAS 适配层 `godot_gas/`

| 文件 | 内容 |
|---|---|
| `attributes/player_stats_attribute_set.gd` | `max_health`、`health`、`damage_bonus`、`burn`、`shield`、`poison`、`regen`；`health` 钳制在 `[0, max_health]`，状态值钳制为不小于 0 |
| `attributes/monster_stats_attribute_set.gd` | 同上，额外有 `cooldown_move`（当前未被使用，移动冷却读的是 `cooldown_effect.duration`） |
| `attributes_draft.cfg` | GodotGAS 编辑器插件的属性草稿数据，不参与运行时 |
| `tag_registry.tres` | 标签注册表：`Event.Combat.Critical`、`State.Burning`、`State.Dead`、`State.Poisoned`、`State.Wounded`、`Team.Enemy`、`Team.Player` |
| `gameplay_tags.gd` | 由插件根据注册表自动生成，**不要手改**；新增标签后通过插件重新生成 |
| `cue_registry.tres` | Cue 注册表，当前为空（没有登记任何特效场景） |

> `addons/GodotGAS/components/ability_system_component.gd` 增加了一个小扩展：`periodic_effect_ticked(active_effect, spec)`，在周期效果每跳 `_commit_spec_math()` 后发出，供 DoT/HoT 的战斗叙事使用。原框架只有施加时的 `effect_received`，没有每跳信号。

标签使用现状：

| 标签 | 使用处 |
|---|---|
| `State.Dead` | `BattleUnit._die()` 添加；效果查询里用来排除尸体 |
| `Event.Combat.Critical` | 直接伤害/护盾等即时效果暴击时 `inject_tag`；`BattleUnit` 用它判断日志和飘字样式。异常状态只在施放时判定暴击，周期 tick 不带此标签 |
| `Team.Player` / `Team.Enemy` | `BattleUnit._init_attributes()` 按 `team` 字段添加 |
| `State.Burning` / `State.Poisoned` | 灼烧/剧毒周期效果的 `granted_tags` |
| `State.Wounded` | 已注册，但当前没有代码使用 |
| `State.Frozen` | `ChargedAbility.FROZEN_TAG`（`BattleBrain.FROZEN_TAG` 别名），**未注册**，也没有 Freeze 效果负责挂/摘 |

GAS 属性：

- 两个 `AttributeSet` 的默认生命值都是 500，但 `BattleUnit._init_attributes()` 会用场景根节点的 `max_health` 覆盖 `max_health` 和 `health` 的 `base_value`。
- `damage_bonus` 是己方魂灵直接伤害加成；`burn` 是当前灼烧层数，按整数层数结算；`shield` 是当前护盾值，无上限；`poison` 是当前剧毒值，按整数结算，每秒且不衰减；`regen` 是当前生命再生值，按整数结算，每秒恢复等量生命且不衰减。
- ASC 在 `_ready()` 时会深拷贝 `attribute_sets`，所以 `BattleUnit` 必须等节点入树后再取 `get_attribute()` 的引用。
- `pre_attribute_change()` 负责下限/上限钳制，`post_attribute_change()` 负责 `max_health` 变化时同步 `health`。
- `BattleUnit._apply_passive_effects()` 在被动最大生命变化后，用运行时 `INSTANT GameplayEffect`（health `ADD health_delta`）同步当前生命，不再直接调用 ASC 内部改属性方法；此时还没连接日志/血条，所以不会产生开场飘字。
