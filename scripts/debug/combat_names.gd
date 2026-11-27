class_name CombatNames extends RefCounted


static func effect_name(spec: GameplayEffectSpec) -> String:
	if spec == null:
		return "未知效果"
	var effect := spec.effect_def
	if effect == null:
		return "未知效果"
	for execution in effect.executions:
		if execution is PeriodicStatusTickExecution:
			return (execution as PeriodicStatusTickExecution).status_display_name()
		if execution is StatusApplyExecution:
			var status_name := (execution as StatusApplyExecution).status_display_name()
			if not status_name.is_empty():
				return status_name
		if execution is HealExecution:
			return "治疗"
		if execution is ShieldExecution:
			return "护盾"
	if effect.granted_tags.has(GameplayTags.State_Frozen):
		return "冻结"
	if effect.granted_tags.has(GameplayTags.State_Swift):
		return "迅捷"
	if effect.granted_tags.has(GameplayTags.State_Sluggish):
		return "迟缓"
	if not spec.display_name.is_empty():
		return spec.display_name
	if not effect.resource_path.is_empty():
		return effect.resource_path.get_file().get_basename()
	return "效果"


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
