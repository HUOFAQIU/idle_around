## 一个单位本场的魂灵装载：槽位、技能、触发器与 SoulRuntime 的统一构建器。
##
## 玩家和怪物走同一条管线，只有槽位来源不同：
##   玩家：BattleWindow 从魂器网格读出 SoulSlot；
##   怪物：不传槽位，按魂灵列表顺序生成一行虚拟魂灵栏。
## BattleUnit 只持有构建结果，不再自己拼装技能/触发器/运行时。
class_name SoulLoadout extends RefCounted

var unit: BattleUnit
var souls: Array[SoulData] = []
## 与 souls 同下标；没有槽位的魂灵为 null
var slots: Array[SoulSlot] = []
## 与 souls 同下标；没有技能的魂灵（被动/未配）为 null
var abilities: Array[AutoCastAbility] = []
## 非空魂灵的运行期状态；玩家魂器网格和调试窗口读这一份
var runtimes: Array[SoulRuntime] = []
## 本场由这些魂灵生成的触发器能力（已 grant 到 ASC）
var triggers: Array[SoulTriggerAbility] = []


func _init(
	owner_unit: BattleUnit,
	soul_list: Array[SoulData],
	provided_slots: Array[SoulSlot] = []
) -> void:
	unit = owner_unit
	souls = soul_list
	slots = provided_slots
	if slots.is_empty():
		slots = SoulSlot.virtual_slots(souls)
	_create_abilities()
	_create_triggers()
	_apply_slots()
	_create_runtimes()


## 开战前收集被动魂灵的属性效果；必须在 setup_from_scene() 之前调用。
static func collect_passive_effects(soul_list: Array[SoulData]) -> Array[GameplayEffect]:
	var effects: Array[GameplayEffect] = []
	for soul in soul_list:
		var passive := soul as PassiveSoulData
		if passive == null:
			continue
		for effect in passive.passive_effects:
			if effect != null:
				effects.append(effect)
	return effects


## 某颗来源魂灵的运行期状态；source_index 与构建时的 souls 下标一致
func runtime_for_source_index(index: int) -> SoulRuntime:
	if index >= 0 and index < runtimes.size():
		return runtimes[index]
	return null


## 是否还有一条指定事件的触发器可用（once_per_battle 已用掉的不算）
func has_trigger(event_tag: StringName) -> bool:
	for trigger_ability in triggers:
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
func has_health_trigger_for(ratio: float) -> bool:
	for trigger_ability in triggers:
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


## 单位销毁/战斗结束：注销运行期状态，避免 ItemView 和调试窗口读到旧对象
func clear() -> void:
	for runtime in runtimes:
		if runtime != null:
			SoulRuntimeDB.unregister(runtime)
	runtimes.clear()


func _create_abilities() -> void:
	abilities.clear()
	for soul in souls:
		var ability: AutoCastAbility = null
		if soul != null and not (soul is PassiveSoulData) and soul.skill != null:
			ability = AutoCastAbility.new()
			ability.apply_definition(soul.skill, soul.item_name)
			ability.soul_data = soul
			unit.brain.add_ability(ability)
		abilities.append(ability)


## 触发器能力不进入 BattleBrain.abilities，只由 ASC.send_gameplay_event() 唤醒
func _create_triggers() -> void:
	triggers.clear()
	for i in mini(souls.size(), abilities.size()):
		var soul := souls[i]
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
				unit
			)
			trigger_ability.owner_asc = unit.asc
			unit.asc.grant_ability(trigger_ability)
			triggers.append(trigger_ability)


## 把魂灵栏位置写进技能，供左右相邻/随机等“选魂灵”规则使用
func _apply_slots() -> void:
	var ability_loadout: Array[ChargedAbility] = []
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
		ability.unit_soul_abilities = ability_loadout


## 被动魂灵也建运行时（ability 为 null），便于显示占格和触发器
func _create_runtimes() -> void:
	runtimes.clear()
	for i in souls.size():
		var soul := souls[i]
		if soul == null:
			continue
		var slot: SoulSlot = slots[i] if i < slots.size() else null
		var ability: ChargedAbility = abilities[i] if i < abilities.size() else null
		var runtime := SoulRuntime.new(soul, slot, ability, unit)
		for trigger_ability in triggers:
			if trigger_ability.source_index == i:
				runtime.triggers.append(trigger_ability)
		if ability is AutoCastAbility:
			(ability as AutoCastAbility).soul_runtime = runtime
		runtimes.append(runtime)
		# 只有玩家魂器网格需要按 SoulData 实例反查运行时（ItemView 绑定）；
		# 怪物的魂灵资源可能被多只怪共享，不能按同一实例 id 注册。
		if unit.team == BattleUnit.Team.PLAYER:
			SoulRuntimeDB.register(runtime)
		if ability != null and unit.battle != null:
			unit.battle.events.soul_runtime_created.emit(unit, ability, runtime)
