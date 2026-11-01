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
var is_dead: bool = false
var _death_queued: bool = false
## 本场从魂灵上生成的触发器能力（grant 到 ASC，监听 GameplayEvent）
var _trigger_abilities: Array[SoulTriggerAbility] = []
## 本场魂灵运行期列表（与装备顺序一致；玩家/怪物都用）
var loadout: Array[SoulRuntime] = []

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
	# 先接遥测信号，后面的 add_soul_abilities() 才能记录能力授予/触发能力
	CombatTelemetry.bind_unit(self)

	brain = get_node("BattleBrain")
	brain.unit = self
	# 场景里的能力节点挂在 ASC 下，入树时已经由框架自动授予；
	# 这里只把它们登记给大脑，供每帧轮询
	for child in asc.get_children():
		if child is GameplayAbility:
			brain.abilities.append(child as GameplayAbility)
	# 场景配置的魂灵 → 技能/运行期状态（玩家场景 souls 为空，由 BattleWindow 从装备读取后调用）
	add_soul_abilities(souls)

	var health_bar := get_node_or_null("HealthBar") as UnitHealthBar
	if health_bar != null:
		health_bar.bind(health_attr, max_health_attr, asc, _bar_color())

	# 头顶名字：场景里有 Name 标签就跟着 unit_name 走
	var name_label := get_node_or_null("Name") as Label
	if name_label != null:
		name_label.text = unit_name

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


## 战场上有单位改变格子：向自己的 ASC 广播 UnitMoved 事件。
func _on_battle_unit_moved(moving_unit: BattleUnit, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if is_dead or battle == null or not battle.is_running or asc == null:
		return
	if moving_unit == null or moving_unit.is_dead or moving_unit.team == team:
		return
	if not _has_trigger(GameplayTags.Event_Movement_UnitMoved):
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
	if not _has_health_trigger_for(ratio):
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
	if not _has_trigger(GameplayTags.Event_Combat_SoulUsed):
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
	for unit in battle.units_of_team(opposing_team(event_target.team)):
		if unit == null or unit.is_dead or unit.asc == null:
			continue
		if not unit._has_trigger(GameplayTags.Event_Combat_FreezeApplied):
			continue
		unit.asc.send_gameplay_event(GameplayTags.Event_Combat_FreezeApplied, {
			"target": event_target,
			"source": self,
			"trace": trace,
		})


## 把魂灵上的触发器变成 SoulTriggerAbility，grant 到 ASC。
## 触发器能力不进入 BattleBrain.abilities，不会被主循环自动施放；
## 只由 ASC.send_gameplay_event() 按 trigger_event_tag 唤醒。
func _create_soul_trigger_abilities(
	soul_list: Array[SoulData],
	abilities: Array[AutoCastAbility]
) -> void:
	_trigger_abilities.clear()
	for i in mini(soul_list.size(), abilities.size()):
		var soul := soul_list[i]
		if soul == null:
			continue
		for trigger in soul.triggers:
			if trigger == null:
				continue
			var trigger_ability := SoulTriggerAbility.new(
				trigger,
				abilities[i],
				soul.item_name,
				i,
				self
			)
			trigger_ability.owner_asc = asc
			asc.grant_ability(trigger_ability)
			_trigger_abilities.append(trigger_ability)


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
	spec.set_set_by_caller_magnitude(PassiveTrigger.MAGNITUDE_TAG, magnitude)
	if suppress_state_log:
		spec.inject_tag(SUPPRESS_STATE_LOG_TAG)
	asc.apply_effect_spec_to_target(spec, target.asc)
	# 触发器造成的冻结同样广播“有怪物被冻结”
	if effect.granted_tags.has(GameplayTags.State_Frozen):
		notify_freeze_applied(target, trace)


## 把一批魂灵变成技能和运行期状态；返回与输入等长的能力数组，null 表示这颗魂灵没有技能。
## slots 留空时按魂灵部位生成虚拟魂灵栏（怪物用）；玩家由 BattleWindow 传入真实槽位。
## 同时登记魂灵触发器；主动魂灵的触发器会绑定到它自己的技能上（用于触发充能）。
func add_soul_abilities(
	soul_list: Array[SoulData],
	slots: Array[SoulSlot] = []
) -> Array[AutoCastAbility]:
	var resolved_slots := slots
	if resolved_slots.is_empty():
		resolved_slots = _build_soul_slots(soul_list)

	var result : Array[AutoCastAbility] = []
	for i in soul_list.size():
		var soul := soul_list[i]
		result.append(null)
		if soul == null or soul is PassiveSoulData or soul.skill == null:
			continue
		var ability := AutoCastAbility.new()
		ability.apply_definition(soul.skill, soul.item_name)
		ability.soul_data = soul
		brain.add_ability(ability)
		result[i] = ability
	_create_soul_trigger_abilities(soul_list, result)
	if battle != null and not battle.unit_moved.is_connected(_on_battle_unit_moved):
		battle.unit_moved.connect(_on_battle_unit_moved)
	apply_soul_slots(resolved_slots, result)
	_build_soul_runtimes(soul_list, resolved_slots, result)
	return result


## 把魂灵栏位置写进技能，供左右相邻/随机等“选魂灵”规则使用。
## slots 与 abilities 同下标；abilities 为 null 表示该魂灵没有技能（被动/未配）。
func apply_soul_slots(slots: Array[SoulSlot], abilities: Array[AutoCastAbility]) -> void:
	var ability_loadout : Array[ChargedAbility] = []
	for ability in abilities:
		if ability != null:
			ability_loadout.append(ability)
	for i in mini(slots.size(), abilities.size()):
		var ability := abilities[i]
		if ability == null or slots[i] == null:
			continue
		ability.soul_container = slots[i].container_name
		ability.soul_column = slots[i].column
		ability.soul_width = slots[i].width
	for ability in ability_loadout:
		ability.soul_loadout = ability_loadout


## 建运行期状态并注册到 SoulRuntimeDB；玩家装备栏和调试窗口读同一份。
## 被动魂灵也建运行时（ability 为 null），便于显示占格和触发器。
func _has_trigger(event_tag: StringName) -> bool:
	for trigger_ability in _trigger_abilities:
		if trigger_ability == null or trigger_ability.trigger_event_tag != event_tag:
			continue
		if (
			trigger_ability.definition != null
			and trigger_ability.definition.once_per_battle
			and trigger_ability.fired
		):
			continue
		return true
	return false


## 当前生命比例是否还能命中至少一个 Health.BelowPercent 触发器
func _has_health_trigger_for(ratio: float) -> bool:
	for trigger_ability in _trigger_abilities:
		if trigger_ability == null or trigger_ability.trigger_event_tag != GameplayTags.Event_Health_BelowPercent:
			continue
		var definition := trigger_ability.definition
		if definition == null:
			continue
		if definition.once_per_battle and trigger_ability.fired:
			continue
		if ratio < definition.threshold_ratio:
			return true
	return false


func runtime_for_source_index(index: int) -> SoulRuntime:
	if index >= 0 and index < loadout.size():
		return loadout[index]
	return null


func _build_soul_runtimes(
	soul_list: Array[SoulData],
	slots: Array[SoulSlot],
	abilities: Array[AutoCastAbility]
) -> void:
	loadout.clear()
	for i in soul_list.size():
		var soul := soul_list[i]
		if soul == null:
			continue
		var slot: SoulSlot = slots[i] if i < slots.size() else null
		var ability: ChargedAbility = abilities[i] if i < abilities.size() else null
		var runtime := SoulRuntime.new(soul, slot, ability, self)
		for trigger_ability in _trigger_abilities:
			if trigger_ability.source_index == i:
				runtime.triggers.append(trigger_ability)
		if ability is AutoCastAbility:
			(ability as AutoCastAbility).soul_runtime = runtime
		loadout.append(runtime)
		# 只有玩家装备栏需要按 SoulData 实例反查运行时（ItemView 绑定）；
		# 怪物的魂灵资源可能被多只怪共享，不能按同一实例 id 注册。
		if team == Team.PLAYER:
			SoulRuntimeDB.register(runtime)
		if ability != null:
			CombatTelemetry.bind_ability(ability, self, runtime)


## 单位销毁/战斗结束：注销运行期状态，避免 ItemView 和调试窗口读到旧对象。
func unregister_soul_runtimes() -> void:
	for runtime in loadout:
		if runtime != null:
			SoulRuntimeDB.unregister(runtime)
	loadout.clear()


## 怪物没有真实的魂灵容器：按配置顺序、按部位分组排成虚拟魂灵栏。
## 只处理实际配置的部位，蛇不会凭空多出手/腿。
func _build_soul_slots(soul_list: Array[SoulData]) -> Array[SoulSlot]:
	var slots : Array[SoulSlot] = []
	var part_columns : Dictionary = {}
	for soul in soul_list:
		if soul == null:
			slots.append(null)
			continue
		var part := soul.equip_part if not soul.equip_part.is_empty() else "ANY"
		var slot := SoulSlot.new()
		slot.soul = soul
		slot.container_name = part
		slot.column = int(part_columns.get(part, 0))
		slot.width = maxi(soul.columns, 1)
		part_columns[part] = slot.column + slot.width
		slots.append(slot)
	return slots


func _connect_asc() -> void:
	asc.attribute_changed.connect(_on_attribute_changed)
	asc.active_effect_added.connect(_on_active_effect_added)
	asc.active_effect_removed.connect(_on_active_effect_removed)
	asc.effect_received.connect(_on_effect_received)
	asc.periodic_effect_ticked.connect(_on_periodic_effect_ticked)


## 血条颜色：敌红我绿
func _bar_color() -> Color:
	return Color(0.40, 0.85, 0.45) if team == Team.PLAYER else Color(0.90, 0.30, 0.25)


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


## 单位级冻结（State.Frozen）：整个单位不充能、不释放、不移动
func is_unit_frozen() -> bool:
	return asc != null and asc.has_tag(GameplayTags.State_Frozen)


## 血量百分比（0~1），TargetRule 的 LOWEST_HP_PERCENT 规则用它排序
func health_percent() -> float:
	return health_attr.current_value / maxf(max_health_attr.current_value, 0.001)


#region 观战日志与死亡
func _log(text: String, color: String = "white") -> void:
	if battle:
		battle.log_line(text, color)


## 效果显示名：灼烧/剧毒周期效果优先显示中文；
## 其余优先 spec 上由技能写入的显示名，再退回 resource_name / 文件名。
func _effect_display_name(spec: GameplayEffectSpec) -> String:
	return CombatNames.effect_name(spec)


## 血条和死亡只看属性变化；伤害/治疗叙事走 effect_received。
## 生命值变化同时驱动“首次低于比例”类魂灵触发器。
func _on_attribute_changed(attribute_name: String, old_value: float, new_value: float, _spec: GameplayEffectSpec) -> void:
	if attribute_name != "health":
		return
	if new_value <= 0.0:
		_queue_death()
	else:
		_check_health_triggers(old_value, new_value)


## 周期效果每跳提交后由 ASC 发出；这里专门处理灼烧的每跳叙事。
## 用 calculated_deltas 拿到经过血量钳制后的真实伤害，不再借用 attribute_changed。
func _on_periodic_effect_ticked(active_effect: ActiveGameplayEffect, spec: GameplayEffectSpec) -> void:
	if spec == null:
		return
	if BurnTickExecution.is_burn_tick_effect(spec.effect_def):
		_handle_burn_tick(spec)
		# 层数归零后移除周期效果：State.Burning 和灼烧火焰 Cue 一起结束
		var burn_attr := asc.get_attribute("burn")
		if burn_attr != null and burn_attr.current_value <= 0.0:
			asc.remove_active_effect(active_effect)
	elif PoisonTickExecution.is_poison_tick_effect(spec.effect_def):
		_handle_poison_tick(spec)
		# 剧毒被治疗净化到 0 后移除周期效果：State.Poisoned 和中毒光环 Cue 一起结束
		var poison_attr := asc.get_attribute("poison")
		if poison_attr != null and poison_attr.current_value <= 0.0:
			asc.remove_active_effect(active_effect)
	elif RegenTickExecution.is_regen_tick_effect(spec.effect_def):
		_handle_regen_tick(spec)


func _handle_burn_tick(spec: GameplayEffectSpec) -> void:
	var health_delta := float(spec.calculated_deltas.get("health", 0.0))
	var shield_delta := float(spec.calculated_deltas.get("shield", 0.0))
	if health_delta >= 0.0 and shield_delta >= 0.0:
		return

	var source_name := _source_name(spec)
	var effect_name := _effect_display_name(spec)
	if shield_delta < 0.0:
		_log_shield_absorb(-shield_delta, source_name, effect_name)
	if health_delta < 0.0:
		_log_burn_tick(-health_delta, spec)


func _handle_poison_tick(spec: GameplayEffectSpec) -> void:
	var health_delta := float(spec.calculated_deltas.get("health", 0.0))
	if health_delta >= 0.0:
		return
	_log_poison_tick(-health_delta, spec)


func _handle_regen_tick(spec: GameplayEffectSpec) -> void:
	var health_delta := float(spec.calculated_deltas.get("health", 0.0))
	if health_delta <= 0.0:
		return
	_log_regen_tick(health_delta, spec)


## 护盾吸收伤害的黄色日志和飘字
func _log_shield_absorb(amount: float, source_name: String, effect_name: String) -> void:
	if amount <= 0.0:
		return
	_log("%s 的护盾吸收 %.0f 点【%s】伤害（来自 %s）"
		% [unit_name, amount, effect_name, source_name], "#ffd60a")
	_pop_number(amount, false, false, false, true)


## 灼烧每跳的实际生命伤害（经过血量钳制后的值）
func _log_burn_tick(damage: float, spec: GameplayEffectSpec) -> void:
	if damage <= 0.0:
		return
	var old_value := health_attr.current_value + damage
	var source_name := _source_name(spec)
	var effect_name := _effect_display_name(spec)
	_log("%s 受到【%s】（来自 %s）%.0f 点伤害，HP %.0f → %.0f"
		% [unit_name, effect_name, source_name, damage, old_value, health_attr.current_value], "#ff6600")
	_pop_number(damage, false, false, true)


## 剧毒每跳：无视护盾，直接扣生命；墨绿日志/飘字。
func _log_poison_tick(damage: float, spec: GameplayEffectSpec) -> void:
	if damage <= 0.0:
		return
	var old_value := health_attr.current_value + damage
	var source_name := _source_name(spec)
	var effect_name := _effect_display_name(spec)
	_log("%s 受到【%s】（来自 %s）%.0f 点伤害，HP %.0f → %.0f"
		% [unit_name, effect_name, source_name, damage, old_value, health_attr.current_value], "#2e6b40")
	_pop_number(damage, false, false, false, false, true)


## 生命再生每跳：恢复生命，不净化；亮绿色日志/飘字。
func _log_regen_tick(damage: float, spec: GameplayEffectSpec) -> void:
	if damage <= 0.0:
		return
	var old_value := health_attr.current_value - damage
	var source_name := _source_name(spec)
	var effect_name := _effect_display_name(spec)
	_log("%s 受到【%s】（来自 %s）影响，恢复 %.0f 点生命，HP %.0f → %.0f"
		% [unit_name, effect_name, source_name, damage, old_value, health_attr.current_value], "#4dff66")
	_pop_number(damage, true, false, false, false, false, true)


func _source_name(spec: GameplayEffectSpec) -> String:
	return CombatNames.source_name(spec)


## 效果生命周期：只有对方真正收到效果时才写伤害/治疗日志和飘字。
## 击杀那一下也要显示，所以这里不因为 is_dead 直接返回。
func _on_effect_received(_source_asc: AbilitySystemComponent, spec: GameplayEffectSpec) -> void:
	if spec == null:
		return
	if spec.effect_def is PassiveEffect:
		return
	# 周期效果在施加时只做了预览计算，并没有真正扣血；
	# 伤害要等每一跳通过 periodic_effect_ticked 单独记账。
	if spec.period > 0.0:
		return
	var health_delta := float(spec.calculated_deltas.get("health", 0.0))
	var shield_delta := float(spec.calculated_deltas.get("shield", 0.0))
	if is_zero_approx(health_delta) and shield_delta >= 0.0:
		return

	var current := health_attr.current_value
	var old_value := current - health_delta
	var source_name := _source_name(spec)
	var effect_name := _effect_display_name(spec)
	var critical := spec.has_tag(GameplayTags.Event_Combat_Critical)
	var crit_suffix := "（暴击）" if critical else ""

	if shield_delta < 0.0:
		_log_shield_absorb(-shield_delta, source_name, effect_name)
	if health_delta < 0.0:
		_log("%s 受到【%s】（来自 %s）%.0f 点伤害%s，HP %.0f → %.0f"
			% [unit_name, effect_name, source_name, -health_delta, crit_suffix, old_value, current], "#ff6e6e")
		_pop_number(-health_delta, false, critical)
	elif health_delta > 0.0:
		_log("%s 回复 %.0f 点生命%s，HP %.0f → %.0f"
			% [unit_name, health_delta, crit_suffix, old_value, current], "#7ddf7d")
		_pop_number(health_delta, true, critical)


## 头顶跳一个数字
func _pop_number(
	amount: float,
	heal: bool,
	critical: bool = false,
	burn: bool = false,
	shield: bool = false,
	poison: bool = false,
	regen: bool = false
) -> void:
	var number := DamageNumber.new()
	add_child(number)  # 先入树，里面建补间要用
	number.setup(amount, heal, critical, burn, shield, poison, regen)


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


## 销毁单位前调用：停技能、清 active effects，避免 GAS 泄漏。
func cleanup_asc() -> void:
	unregister_soul_runtimes()
	if asc != null:
		asc.cleanup()


func _on_active_effect_added(active_effect: ActiveGameplayEffect) -> void:
	var def := active_effect.get_effect_def()
	if is_dead or def == null or def.policy == GameplayEffect.DurationPolicy.INSTANT or def is PassiveEffect:
		return
	if _has_suppressed_state_log(active_effect):
		return
	var duration_text := "持续" if def.policy == GameplayEffect.DurationPolicy.INFINITE else "%.1f 秒" % active_effect.time_remaining
	_log("%s 获得状态【%s】（%s）" % [unit_name, _effect_display_name(active_effect.spec), duration_text], "#57d9e8")


func _on_active_effect_removed(active_effect: ActiveGameplayEffect) -> void:
	var def := active_effect.get_effect_def()
	if is_dead or def == null or def.policy == GameplayEffect.DurationPolicy.INSTANT or def is PassiveEffect:
		return
	if _has_suppressed_state_log(active_effect):
		return
	_log("%s 的状态【%s】结束" % [unit_name, _effect_display_name(active_effect.spec)], "gray")


## 批量触发施加的效果不逐目标写状态日志，避免全体冻结时刷屏
func _has_suppressed_state_log(active_effect: ActiveGameplayEffect) -> bool:
	return (
		active_effect != null
		and active_effect.spec != null
		and active_effect.spec.has_tag(SUPPRESS_STATE_LOG_TAG)
	)


func _die() -> void:
	is_dead = true
	asc.add_tag(GameplayTags.State_Dead)
	if brain != null:
		brain.set_process(false)
		brain.set_physics_process(false)
	_log("%s 倒下了！" % unit_name, "#ffcc44")
	died.emit(self)
#endregion
