class_name SoulDamagePreview
extends RefCounted
## 魂灵直接伤害的展示预览：技能静态数据 + 当前装备/战斗运行期加成。
##
## 与 `SoulDamageExecution` 共用同一套公式，避免 tooltip 和战斗各写一份。
## 魂器窗口内标记 `is_dynamic`：能通过 `SoulRuntimeDB` 拿到运行期实例时用运行期值；
## 否则按“装上这份魂器后”做静态预览。仓库、背包、见闻等没有装备上下文的地方退回基础值。

## 技能资源里的基础伤害（正数）
var base_damage: float = 0.0
## 每有一颗匹配类型的魂灵额外增加的伤害
var bonus_per_matching_soul: float = 0.0
## 匹配的魂灵类型（SoulData.types）
var matching_soul_types: Array[StringName] = []
## 当前魂器网格里匹配的魂灵数量；恐狼自己也算一颗
var matching_soul_count: int = 0
## 玩家 ASC 的全局直接伤害加成
var player_damage_bonus: float = 0.0
## 来源魂器提供的直接伤害加成
var vessel_damage_bonus: float = 0.0
## 技能里是否有直接伤害执行
var has_damage: bool = false
## 是否叠加了当前装备上下文；决定 tooltip 是否显示动态数值
var is_dynamic: bool = false
## 是否来自战斗运行期实例（最准，含临时 buff）
var has_runtime: bool = false


## 只读技能资源，不叠加任何运行期加成
static func base_for(skill: SkillDefinition) -> SoulDamagePreview:
	var preview := SoulDamagePreview.new()
	var execution := find_damage_execution(skill)
	if execution == null:
		return preview
	preview.has_damage = true
	preview.base_damage = execution.base_damage
	preview.bonus_per_matching_soul = execution.bonus_per_matching_soul
	preview.matching_soul_types = execution.matching_soul_types.duplicate()
	return preview


## 叠加运行时加成；runtime 为空或已失效时退回基础值
static func for_soul(soul: SoulData, runtime: SoulRuntime) -> SoulDamagePreview:
	var preview := base_for(soul.skill if soul != null else null)
	if runtime == null or not is_instance_valid(runtime.owner_unit):
		return preview
	var unit := runtime.owner_unit
	preview.is_dynamic = true
	preview.has_runtime = true
	preview.matching_soul_count = SoulDamageExecution.matching_soul_count(
		unit.loadout, preview.matching_soul_types
	)
	preview.player_damage_bonus = _player_damage_bonus(unit)
	preview.vessel_damage_bonus = maxf(runtime.vessel_damage_bonus, 0.0)
	return preview


## 按“把这颗魂灵所在魂器装到角色上”做静态预览。
##
## 匹配数量与玩家被动加成用当前角色魂器网格 + 这份魂器的魂灵（按实例去重），
## 魂器加成取这份魂器。玩家被动只汇总 `modifiers` 里的 STATIC 数值；
## 动态 magnitude / 自定义 execution 需要运行期 ASC，预览不到。
static func preview_for(
	soul: SoulData,
	vessel: SoulVesselData,
	equipped_souls: Array[SoulData]
) -> SoulDamagePreview:
	var preview := base_for(soul.skill if soul != null else null)
	if soul == null:
		return preview
	var souls: Array[SoulData] = equipped_souls.duplicate()
	if vessel != null:
		for item in vessel.ensure_contents().items:
			if item is SoulData and not souls.has(item):
				souls.append(item as SoulData)
	if not souls.has(soul):
		souls.append(soul)
	preview.is_dynamic = true
	preview.matching_soul_count = _matching_soul_count(souls, preview.matching_soul_types)
	preview.player_damage_bonus = _passive_damage_bonus(SoulLoadout.collect_passive_effects(souls))
	preview.vessel_damage_bonus = maxf(vessel.soul_damage_bonus(), 0.0) if vessel != null else 0.0
	return preview


## 暴击前的最终伤害；与战斗落地口径一致向下取整
func total() -> float:
	var soul_bonus := float(matching_soul_count) * bonus_per_matching_soul
	return floorf(SoulDamageExecution.total_before_crit(
		base_damage, player_damage_bonus, soul_bonus, vessel_damage_bonus
	))


## 技能里第一个直接伤害执行；没有时返回 null
static func find_damage_execution(skill: SkillDefinition) -> SoulDamageExecution:
	if skill == null:
		return null
	for step in skill.steps:
		if not step is UnitSkillStep:
			continue
		for effect in (step as UnitSkillStep).effects:
			if effect == null:
				continue
			for execution in effect.executions:
				if execution is SoulDamageExecution:
					return execution as SoulDamageExecution
	return null


static func _player_damage_bonus(unit: BattleUnit) -> float:
	if unit == null or unit.asc == null:
		return 0.0
	var attr := unit.asc.get_attribute("damage_bonus")
	return maxf(attr.current_value, 0.0) if attr != null else 0.0


## 按 GAS 的聚合规则静态汇总玩家 damage_bonus；只处理 STATIC 修饰。
## 公式与 `AbilitySystemComponent._aggregate_attribute_value()` 保持一致：
## (base + ADD) * (1 + PERCENT_ADD) * MULTIPLY / DIVIDE，OVERRIDE 优先。
static func _passive_damage_bonus(effects: Array[GameplayEffect]) -> float:
	var addition := 0.0
	var percent_addition := 0.0
	var multiplication := 1.0
	var division := 1.0
	var has_override := false
	var override_priority := -2147483648
	var override_value := -INF
	for effect in effects:
		if effect == null:
			continue
		for modifier in effect.modifiers:
			if modifier == null or modifier.attribute_name != "damage_bonus":
				continue
			if modifier.magnitude_calculation != GameplayEffectModifier.MagnitudeCalculationType.STATIC:
				continue
			var magnitude := modifier.calculate_magnitude(1.0)
			match modifier.operation:
				GameplayEffectModifier.Operation.ADD:
					addition += magnitude
				GameplayEffectModifier.Operation.PERCENT_ADD:
					percent_addition += magnitude
				GameplayEffectModifier.Operation.MULTIPLY:
					multiplication *= magnitude
				GameplayEffectModifier.Operation.DIVIDE:
					if not is_zero_approx(magnitude):
						division *= magnitude
				GameplayEffectModifier.Operation.OVERRIDE:
					if (
						not has_override
						or modifier.override_priority > override_priority
						or (
							modifier.override_priority == override_priority
							and magnitude > override_value
						)
					):
						has_override = true
						override_priority = modifier.override_priority
						override_value = magnitude
	var value := override_value if has_override else addition * (1.0 + percent_addition) * multiplication / division
	return maxf(floorf(value), 0.0)


## 数魂灵列表里带匹配类型的数量；恐狼自己也算一颗
static func _matching_soul_count(souls: Array[SoulData], matching_types: Array[StringName]) -> int:
	var count := 0
	for soul in souls:
		if _soul_matches(soul, matching_types):
			count += 1
	return count


static func _soul_matches(soul: SoulData, matching_types: Array[StringName]) -> bool:
	if soul == null:
		return false
	for soul_type in matching_types:
		if soul.types.has(soul_type):
			return true
	return false
