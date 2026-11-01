## 调试/日志用的统一显示名。
##
## 效果名优先用 spec.display_name（由技能/触发器写入），其次按 execution
## 类型识别灼烧/剧毒/再生，最后退回效果资源文件名。不要在别处再写一套。
class_name CombatNames extends RefCounted


static func effect_name(spec: GameplayEffectSpec) -> String:
	if spec == null:
		return "未知效果"
	var effect := spec.effect_def
	if effect == null:
		return "未知效果"
	# 先按 execution 类型给状态/周期效果一个稳定名字；
	# spec.display_name 是技能/魂灵名，留给普通伤害/治疗这类效果。
	for execution in effect.executions:
		if execution is StatusApplyExecution:
			match (execution as StatusApplyExecution).attribute_name:
				"burn":
					return "灼烧"
				"poison":
					return "剧毒"
				"regen":
					return "生命再生"
		if execution is BurnTickExecution:
			return "灼烧"
		if execution is PoisonTickExecution:
			return "剧毒"
		if execution is RegenTickExecution:
			return "生命再生"
		if execution is RegenFromBurnExecution:
			return "生命再生"
		if execution is HealExecution:
			return "治疗"
		if execution is ShieldExecution:
			return "护盾"
	if effect.granted_tags.has(GameplayTags.State_Frozen):
		return "冻结"
	if not spec.display_name.is_empty():
		return spec.display_name
	if not effect.resource_path.is_empty():
		return effect.resource_path.get_file().get_basename()
	return "效果"


## 效果来源单位名；周期效果可能比施加者活得久，先判有效。
static func source_name(spec: GameplayEffectSpec) -> String:
	if spec == null or spec.context == null:
		return "未知来源"
	var instigator = spec.context.instigator
	if is_instance_valid(instigator) and instigator is BattleUnit:
		return (instigator as BattleUnit).unit_name
	var causer = spec.context.causer
	if is_instance_valid(causer) and causer is BattleUnit:
		return (causer as BattleUnit).unit_name
	return "未知来源"


static func ability_name(ability: GameplayAbility) -> String:
	if ability == null:
		return "???"
	if not ability.ability_name.is_empty():
		return ability.ability_name
	if not ability.ability_tag.is_empty():
		return String(ability.ability_tag)
	return ability.name
