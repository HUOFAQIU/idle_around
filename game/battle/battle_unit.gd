## 战斗单位：战场上的一个 token，逻辑和表现都在它身上。
##
## 节点结构（有框架强约束）：
##   BattleUnit (CharacterBody2D) ← 实时位置；带碰撞体，和别的单位互推/阻挡
##   ├── AbilitySystemComponent   ← 名字必须精确叫这个！
##                                   框架在解析"施法者→ASC"时用的是
##                                   get_node_or_null("AbilitySystemComponent")
##                                   属性集配在它的 attribute_sets 上
##   ├── BattleBrain              ← 自动施法
##   ├── HealthBar (UnitHealthBar)← 血条（可选，有就绑上）
##   ├── Body (Sprite2D)          ← 本体贴图（可选，纯显示）
##   └── Name (Label)             ← 头顶名字（可选，有就自动填 unit_name）
##
## 位置：战斗改即时制后，单位用 position（像素）作为真实位置；
## cell 只记录“当前压在地图哪一格”，用于刷怪、调试和 ENEMY_MOVED 这类按格触发的事件。
## 移动由 BattleManager 统一驱动，单位自己是 CharacterBody2D，负责和别的单位碰撞。

class_name BattleUnit extends CharacterBody2D

## 单位倒下时发出
signal died(unit: BattleUnit)
## 单位跨入新的地图格时发出（实时移动中由 BattleManager 在换格时触发）。
## 出生/瞬移用的 set_cell() 不触发。
signal moved(unit: BattleUnit, from_cell: Vector2i, to_cell: Vector2i)

enum Team { PLAYER, ENEMY }

## 批量触发时的临时 spec 标记：不逐目标写“获得/结束状态”日志
const SUPPRESS_STATE_LOG_TAG : StringName = &"Data.SuppressStateLog"

@export var unit_name: String = ""
@export var team: Team = Team.PLAYER
## 血量上限（在场景根节点上配置）
@export var max_health: float = 100.0
## 死亡掉落（怪物场景里配置；玩家留空）
@export var drops: Array[DropEntry] = []
## 场景配置的魂灵（怪物用；玩家场景留空，运行时从装备读取）
@export var souls: Array[SoulData] = []

## 攻击范围（像素，圆心到圆心）。怪物只有在这个距离内才会开始给魂灵充能。
## 约等于一格（地图格宽 32px），和 TargetRule 的 max_range 口径保持一致。
@export var attack_range: float = 30.0
## 移动速度（像素/秒）。默认约等于旧版“3 秒走一格”。
@export var move_speed: float = 11.0

var battle: BattleManager
var asc: AbilitySystemComponent
var brain: BattleBrain
## 表现层：血条/染色/名字/飘字；随单位一起释放
var _presenter: UnitPresenter
var is_dead: bool = false
var _death_queued: bool = false
## 本场魂灵装载（槽位、技能、触发器、运行期状态）；由 add_soul_abilities() 创建
var soul_loadout: SoulLoadout

## 本场魂灵运行期列表（与装备顺序一致；玩家/怪物都用）
var loadout: Array[SoulRuntime]:
	get:
		if soul_loadout == null:
			return []
		return soul_loadout.runtimes

## 战场格子坐标（逻辑位置）
var cell: Vector2i = Vector2i.ZERO

## 缓存（ASC _ready 会深拷贝属性集，所以要在 add_child 之后再取引用）
var health_attr: AttributeData
var max_health_attr: AttributeData
var shield_attr: AttributeData


## 与指定阵营敌对的阵营
static func opposing_team(team_id: Team) -> Team:
	return Team.ENEMY if team_id == Team.PLAYER else Team.PLAYER


## 从场景建号：ASC、外观、能力都由场景预先配置。
## 场景根节点已经入树（子节点的 _ready 跑过）之后调用。
## passive_effects 只给玩家用：开战前挂属性效果，不写开场状态日志。
## 魂灵触发器在 add_soul_abilities() 里按“来源魂灵 + 技能”统一登记。
func setup_from_scene(
	p_battle: BattleManager,
	passive_effects: Array[GameplayEffect] = []
) -> void:
	battle = p_battle

	asc = get_node("AbilitySystemComponent")
	# 属性集配在场景的 ASC 节点上，入树时框架已经深拷贝好；这里只写初始数值
	_init_attributes()
	_apply_passive_effects(passive_effects)
	# 先让观察者接上 GAS 信号，后面的 add_soul_abilities() 才能记录能力授予/触发能力
	battle.events.unit_asc_ready.emit(self)

	brain = get_node("BattleBrain")
	brain.unit = self
	# 场景里的能力节点挂在 ASC 下，入树时已经由框架自动授予；
	# 这里只把它们登记给大脑，供每帧轮询
	for child in asc.get_children():
		if child is GameplayAbility:
			brain.abilities.append(child as GameplayAbility)
	# 场景配置的魂灵 → 技能/运行期状态（玩家场景 souls 为空，由 BattleWindow 从装备读取后调用）
	add_soul_abilities(souls)

	# 表现（血条/染色/名字/飘字）交给 presenter，单位本身只保留战斗身份
	_presenter = UnitPresenter.new(self)
	_presenter.name = "Presenter"
	add_child(_presenter)

	_connect_asc()


## ASC 入树之后写初始属性：先设上限，血量的钳制依赖它
func _init_attributes() -> void:
	asc.get_attribute("max_health").base_value = max_health
	asc.get_attribute("health").base_value = max_health

	health_attr = asc.get_attribute("health")
	max_health_attr = asc.get_attribute("max_health")
	shield_attr = asc.get_attribute("shield")

	# 阵营标签（本案例逻辑以 team 字段为准；标签留给未来的标签过滤器用）
	asc.add_tag(GameplayTags.Team_Player if team == Team.PLAYER else GameplayTags.Team_Enemy)


## 开战前挂被动效果。上限变化时按原生命百分比同步当前生命。
## 此时还没 _connect_asc()，也还没 bind 血条，所以不会产生状态日志。
func _apply_passive_effects(effects: Array[GameplayEffect]) -> void:
	if effects.is_empty():
		return
	var health_ratio := health_attr.current_value / maxf(max_health_attr.current_value, 0.001)
	var max_before := max_health_attr.current_value
	for effect in effects:
		if effect != null:
			# 被动效果用 PassiveEffect 类型标记，不写“获得/结束状态”日志
			asc.apply_gameplay_effect(effect, asc)
	if not is_equal_approx(max_before, max_health_attr.current_value):
		# 用瞬时 GameplayEffect 同步当前生命，仍然走 GAS 的钳制和重算。
		# 此时还未连接日志/血条，不会产生开场飘字。
		var target_health := max_health_attr.current_value * health_ratio
		var health_delta := target_health - health_attr.current_value
		_apply_health_delta_effect(health_delta)


## 用运行时 INSTANT 效果修改生命，避免绕过 GameplayEffect 直接写属性。
func _apply_health_delta_effect(health_delta: float) -> void:
	if is_zero_approx(health_delta) or asc == null:
		return
	var sync_effect := GameplayEffect.new()
	sync_effect.policy = GameplayEffect.DurationPolicy.INSTANT
	var modifier := GameplayEffectModifier.new()
	modifier.attribute_name = "health"
	modifier.operation = GameplayEffectModifier.Operation.ADD
	modifier.magnitude = health_delta
	sync_effect.modifiers.append(modifier)
	asc.apply_gameplay_effect(sync_effect, asc)


## 战场上有敌方单位改变格子；由 BattleManager 只派发给注册了 UnitMoved 触发器的单位。
func on_enemy_moved(moving_unit: BattleUnit, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if is_dead or battle == null or not battle.is_running or asc == null:
		return
	if moving_unit == null or moving_unit.is_dead or moving_unit.team == team:
		return
	if soul_loadout == null or not soul_loadout.has_trigger(GameplayTags.Event_Movement_UnitMoved):
		return
	var trace := CombatTrace.new("event:UnitMoved", null)
	asc.send_gameplay_event(GameplayTags.Event_Movement_UnitMoved, {
		"target": moving_unit,
		"from_cell": from_cell,
		"to_cell": to_cell,
		"trace": trace,
	})


## 生命值变化：向自己的 ASC 广播 Health.BelowPercent 事件。
## 只在生命下降时发；具体阈值由每个 SoulTriggerAbility 判断。
func _check_health_triggers(old_value: float, new_value: float) -> void:
	if is_dead or asc == null or max_health_attr == null or new_value <= 0.0:
		return
	if new_value >= old_value:
		return
	var max_hp := max_health_attr.current_value
	if max_hp <= 0.0:
		return
	var ratio := new_value / max_hp
	if soul_loadout == null or not soul_loadout.has_health_trigger_for(ratio):
		return
	var trace := CombatTrace.new("event:HealthBelowPercent", null)
	asc.send_gameplay_event(GameplayTags.Event_Health_BelowPercent, {
		"target": self,
		"old": old_value,
		"new": new_value,
		"ratio": ratio,
		"trace": trace,
	})


## 某个魂灵技能成功激活（含空放）：向自己的 ASC 广播 SoulUsed 事件。
func notify_soul_used(used: ChargedAbility, parent_trace: CombatTrace = null) -> void:
	if is_dead or battle == null or not battle.is_running or asc == null:
		return
	if soul_loadout == null or not soul_loadout.has_trigger(GameplayTags.Event_Combat_SoulUsed):
		return
	var trace := parent_trace if parent_trace != null else CombatTrace.new("event:SoulUsed", null)
	var used_soul: SoulData = null
	if used is AutoCastAbility:
		used_soul = (used as AutoCastAbility).soul_data
	asc.send_gameplay_event(GameplayTags.Event_Combat_SoulUsed, {
		"target": self,
		"used_ability": used,
		"used_soul": used_soul,
		"trace": trace,
	})


## 有单位被冻结：向所有“以该单位为敌”的单位广播 FreezeApplied 事件。
## 不区分冻结来源，只要怪物被冻住就按只数触发；重复冻结同一目标也算一次。
func notify_freeze_applied(event_target: BattleUnit, parent_trace: CombatTrace = null) -> void:
	if battle == null or not battle.is_running or event_target == null:
		return
	var trace := parent_trace if parent_trace != null else CombatTrace.new("event:FreezeApplied", null)
	for unit in battle.trigger_listeners(GameplayTags.Event_Combat_FreezeApplied):
		if unit.team == event_target.team or unit.asc == null:
			continue
		if unit.soul_loadout == null or not unit.soul_loadout.has_trigger(GameplayTags.Event_Combat_FreezeApplied):
			continue
		unit.asc.send_gameplay_event(GameplayTags.Event_Combat_FreezeApplied, {
			"target": event_target,
			"source": self,
			"trace": trace,
		})


## 触发器效果对单个目标施加。事件来源是触发器所属单位。
## 触发施加的灼烧不写暴击率；主动技能会自己把暴击率写进 spec。
## 批量施加时 suppress_state_log = true：目标不逐条写“获得/结束状态”日志。
func apply_trigger_effect(
	effect: GameplayEffect,
	target: BattleUnit,
	magnitude: float,
	suppress_state_log: bool = false,
	trace: CombatTrace = null,
	display_name: String = ""
) -> void:
	if effect == null or asc == null or target == null or target.asc == null:
		return
	var context := SoulEffectContext.new(self, self, trace)
	context.target_data.append_node(target)
	var spec := GameplayEffectSpec.new(effect, context, 1.0)
	if not display_name.is_empty():
		spec.display_name = display_name
	spec.set_set_by_caller_magnitude(GameplayTags.Data_TriggerMagnitude, magnitude)
	if suppress_state_log:
		spec.inject_tag(SUPPRESS_STATE_LOG_TAG)
	asc.apply_effect_spec_to_target(spec, target.asc)
	# 触发器造成的冻结同样广播“有怪物被冻结”
	if effect.granted_tags.has(GameplayTags.State_Frozen):
		notify_freeze_applied(target, trace)


## 把一批魂灵变成技能和运行期状态；返回与输入等长的能力数组，null 表示这颗魂灵没有技能。
## slots 留空时按魂灵部位生成虚拟魂灵栏（怪物用）；玩家由 BattleWindow 传入真实槽位。
func add_soul_abilities(
	soul_list: Array[SoulData],
	slots: Array[SoulSlot] = []
) -> Array[AutoCastAbility]:
	soul_loadout = SoulLoadout.new(self, soul_list, slots)
	_refresh_trigger_listeners()
	return soul_loadout.abilities


## 只有带广播型触发器（UnitMoved / FreezeApplied）的单位才注册监听
func _refresh_trigger_listeners() -> void:
	if battle == null:
		return
	_sync_trigger_listener(GameplayTags.Event_Movement_UnitMoved)
	_sync_trigger_listener(GameplayTags.Event_Combat_FreezeApplied)


func _sync_trigger_listener(event_tag: StringName) -> void:
	var enabled := soul_loadout != null and soul_loadout.has_trigger(event_tag)
	battle.set_trigger_listener(self, event_tag, enabled)


func _clear_trigger_listeners() -> void:
	if battle == null:
		return
	battle.set_trigger_listener(self, GameplayTags.Event_Movement_UnitMoved, false)
	battle.set_trigger_listener(self, GameplayTags.Event_Combat_FreezeApplied, false)


## 某颗来源魂灵的运行期状态；source_index 与构建时的魂灵顺序一致
func runtime_for_source_index(index: int) -> SoulRuntime:
	return soul_loadout.runtime_for_source_index(index) if soul_loadout != null else null


## 单位销毁/战斗结束：注销运行期状态，避免 ItemView 和调试窗口读到旧对象
func unregister_soul_runtimes() -> void:
	if soul_loadout == null:
		return
	soul_loadout.clear()
	soul_loadout = null


func _connect_asc() -> void:
	asc.attribute_changed.connect(_on_attribute_changed)
	asc.periodic_effect_ticked.connect(_on_periodic_effect_ticked)


## 放到某个格子上（出生/瞬移用，瞬时）。实时移动不经过这里。
func set_cell(p_cell: Vector2i) -> void:
	cell = p_cell
	position = battle.cell_to_world(p_cell)


## 到另一个单位的中心距离（像素）
func distance_to_unit(other: BattleUnit) -> float:
	if other == null:
		return INF
	return position.distance_to(other.position)


## 目标是否在自己的攻击范围内（按圆心距离）
func is_in_attack_range(other: BattleUnit) -> bool:
	return other != null and distance_to_unit(other) <= attack_range


## 这一击是否已经把生命打到 0（死亡延迟到帧末处理）
func is_dying() -> bool:
	return is_dead or (health_attr != null and health_attr.current_value <= 0.0)


## 单位级冻结（State.Frozen）：整个单位不充能、不释放、不移动
func is_unit_frozen() -> bool:
	return asc != null and asc.has_tag(GameplayTags.State_Frozen)


## 血量百分比（0~1），TargetRule 的 LOWEST_HP_PERCENT 规则用它排序
func health_percent() -> float:
	return health_attr.current_value / maxf(max_health_attr.current_value, 0.001)


#region 死亡与周期状态
## 血条和死亡只看属性变化；伤害/治疗叙事由 CombatNarrator 订阅 ASC 信号。
## 生命值变化同时驱动“首次低于比例”类魂灵触发器。
func _on_attribute_changed(attribute_name: String, old_value: float, new_value: float, _spec: GameplayEffectSpec) -> void:
	if attribute_name != "health":
		return
	if new_value <= 0.0:
		_queue_death()
	else:
		_check_health_triggers(old_value, new_value)


## 周期效果每跳提交后由 ASC 发出；这里只负责归零移除，叙事由 CombatNarrator 订阅同一信号。
func _on_periodic_effect_ticked(active_effect: ActiveGameplayEffect, spec: GameplayEffectSpec) -> void:
	if spec == null:
		return
	var tick := PeriodicStatusTickExecution.find(spec.effect_def)
	if tick == null or not tick.remove_when_zero():
		return
	var attr := asc.get_attribute(tick.status_attribute())
	if attr != null and attr.current_value <= 0.0:
		asc.remove_active_effect(active_effect)


## 延迟一帧确认死亡：先让 effect_received 写伤害日志，再写“倒下”；
## 同帧内又被治疗回正的话就不死。
func _queue_death() -> void:
	if _death_queued:
		return
	_death_queued = true
	_die_deferred.call_deferred()


func _die_deferred() -> void:
	_death_queued = false
	if is_dead or health_attr == null or health_attr.current_value > 0.0:
		return
	_die()


## 销毁单位前调用：撤销广播监听、停技能、清 active effects，避免 GAS 泄漏。
func cleanup_asc() -> void:
	_clear_trigger_listeners()
	unregister_soul_runtimes()
	if asc != null:
		asc.cleanup()


func _die() -> void:
	is_dead = true
	asc.add_tag(GameplayTags.State_Dead)
	if brain != null:
		brain.set_process(false)
		brain.set_physics_process(false)
	died.emit(self)
#endregion
