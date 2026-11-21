# GAS 适配层

> 类型：实现 | 状态：有效 | 核对：2026-11-21
> 何时读：改属性集、标签注册、Cue 清单
> 关键词：GAS GameplayAbility AttributeSet Tag Cue godot_gas
> 代码：godot_gas/、base_mods/core/mod.json
> 相关：`特效/effects.md`、`架构/调试与遥测.md`

## 1. GAS 适配层 `godot_gas/`

- 静态汇总玩家 `damage_bonus` 时必须复刻 `ASC._aggregate_attribute_value()` 的相乘顺序与 OVERRIDE 优先级，否则预览值和实际伤害会不一致。

| 文件 | 内容 |
|---|---|
| `attributes/player_stats_attribute_set.gd` | `max_health`、`health`、`damage_bonus`、`burn`、`shield`、`poison`、`regen`；`health` 钳制在 `[0, max_health]`，状态值钳制为不小于 0 |
| `attributes/monster_stats_attribute_set.gd` | `max_health`、`health`、`burn`、`shield`、`poison`、`regen`；没有 `damage_bonus` |
| `attributes_draft.cfg` | GodotGAS 编辑器插件的属性草稿数据，不参与运行时 |
| `tag_registry.tres` | 标签注册表：`Cue.*`、`Data.*`（SetByCaller）、`Event.*`（GameplayEvent）、`State.*`、`Team.*`、`Skill.<id>`、`Skill.Trigger.*`；完整列表以此文件为准 |
| `gameplay_tags.gd` | 由插件根据注册表自动生成，**不要手改**；新增标签后通过插件重新生成 |
| `cue_registry.tres` | 项目内置 Cue 注册表，当前为空；官方 Cue 在 `base_mods/core/mod.json`，第三方在自己的 `mod.json` |

> `addons/GodotGAS/components/ability_system_component.gd` 增加了一个小扩展：`periodic_effect_ticked(active_effect, spec)`，在周期效果每跳 `_commit_spec_math()` 后发出，供 DoT/HoT 的战斗叙事使用。原框架只有施加时的 `effect_received`，没有每跳信号。
>
> `addons/GodotGAS/managers/gameplay_cue_manager.gd` 和 `utilities/project_settings.gd` 里直接引用 `EditorInterface` 的地方已改成 `Engine.get_singleton("EditorInterface")`，否则导出模板编译失败、所有 Cue 消失；`gameplay_cue_manager.gd` 的 `remove_persistent_cue` / `set_cue_state` 也改成允许已释放实例。升级 addon 时保留这些修改。

标签使用现状：

| 标签 | 使用处 |
|---|---|
| `State.Dead` | `BattleUnit._die()` 添加；效果查询里用来排除尸体 |
| `Event.Combat.Critical` | 直接伤害/护盾等即时效果暴击时 `inject_tag`；`BattleUnit` 用它判断日志样式，`UnitPresenter` 用它判断飘字样式。异常状态只在施放时判定暴击，周期 tick 不带此标签 |
| `Team.Player` / `Team.Enemy` | `BattleUnit._init_attributes()` 按 `team` 字段添加 |
| `State.Burning` / `State.Poisoned` | 灼烧/剧毒周期效果的 `granted_tags` |
| `State.Frozen` | `ChargedAbility.FROZEN_TAG`（`BattleBrain.FROZEN_TAG` 别名）；单位级冻结由 `freeze_unit.tres` 挂/摘，同时驱动 `Cue.Status.Freeze` |
| `Cue.Status.Freeze` | 单位冻结持久光环（`base_mods/core/cues/freeze_cue.tscn`） |
| `Cue.Combat.ClawSlash` | 命中爪痕（`base_mods/core/cues/claw_slash_cue.tscn`）；由技能资源的 `hit_cue_tag` 触发，带方向/位置 |
| `Event.Movement.UnitMoved` | 敌方跨格；`BattleUnit.on_enemy_moved()` 接收，`BattleManager` 只派发给注册了该触发器的单位 |
| `Event.Health.BelowPercent` | 生命下降；`BattleUnit._check_health_triggers()` 发送 |
| `Event.Combat.SoulUsed` | 魂灵成功激活；`AutoCastAbility._notify_soul_used()` 发送 |
| `Event.Combat.FreezeApplied` | 单位被冻结；`BattleUnit.notify_freeze_applied()` 发送 |
| `Event.Combat.SlowApplied` | 魂灵级减速施加；`ChargedAbility.apply_slow()` → `BattleUnit.notify_slow_applied()` 发送 |
| `Data.TriggerMagnitude` / `Data.SkillMagnitude` / `Data.CritMultiplier` / `Data.SuppressStateLog` | 触发数值 / 主动技能步骤数值 / 暴击倍率 / 批量日志抑制的 SetByCaller 键 |

执行器统一通过 `CritResolution`（`game/battle/crit_resolution.gd`）读取暴击倍率，并在暴击时注入 `Event.Combat.Critical`；SetByCaller 键统一使用自动生成的 `GameplayTags.Data_*`，不要手写字符串。`StatusApplyExecution` 的数值优先级：`Data.SkillMagnitude` > `Data.TriggerMagnitude` > 效果资源 `base_amount`，再乘暴击倍率。

GAS 属性：

- 两个 `AttributeSet` 的默认生命值都是 500，但 `BattleUnit._init_attributes()` 会先把场景根节点的 `max_health` 向下取整，再用它覆盖 `max_health` 和 `health` 的 `base_value`。
- 所有战斗属性落地值都是整数：计算层（暴击、比例、百分比加成等）允许小数，写入属性前统一向下取整。`max_health` 受百分比加成影响时也按最终值取整。
- `damage_bonus` 是己方魂灵直接伤害加成；`burn` 是当前灼烧层数，按整数层数结算；`shield` 是当前护盾值，无上限；`poison` 是当前剧毒值，按整数结算，每秒且不衰减；`regen` 是当前生命再生值，按整数结算，每秒恢复等量生命且不衰减。剧毒与生命再生属性各自保留原值，结算时直接相减，数值大的一方生效。
- ASC 在 `_ready()` 时会深拷贝 `attribute_sets`，所以 `BattleUnit` 必须等节点入树后再取 `get_attribute()` 的引用。
- `pre_attribute_change()` 负责向下取整（`health` 先 clamp 再 floor）与下限/上限钳制；`post_attribute_change()` 负责 `max_health` 变化时同步 `health`。
- `BattleUnit._apply_passive_effects()` 在被动最大生命变化后，用运行时 `INSTANT GameplayEffect`（health `ADD health_delta`）同步当前生命；同步目标生命同样向下取整。此时还没连接日志/血条，所以不会产生开场飘字。

调试接入：`BattleUnit` 在 ASC 就绪时发 `BattleEventBus.unit_asc_ready`，`CombatTelemetryAdapter` 收到后调用 `CombatTelemetry.bind_unit()` 监听 ASC 的属性/标签/效果/能力/GameplayEvent 信号；项目侧创建的 spec 使用 `SoulEffectContext`（`GameplayEffectContext` 子类）携带 `CombatTrace`，调试窗口据此还原因果链。详见 `架构/调试与遥测.md`。
