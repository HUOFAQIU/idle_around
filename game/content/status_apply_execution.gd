class_name StatusApplyExecution extends GameplayExecutionCalculation

## 要写入的状态属性名：burn / poison / regen
@export var attribute_name: String = "burn"
## 主动技能没有 SetByCaller 时使用的基础数值
@export var base_amount: float = 0.0


func execute(spec: GameplayEffectSpec, _target_asc: AbilitySystemComponent) -> Dictionary:
	if attribute_name.is_empty():
		return {}

	var amount := resolve_amount(spec)
	if amount <= 0.0:
		return {}
	return {attribute_name: amount}


func resolve_amount(spec: GameplayEffectSpec) -> float:
	var amount := base_amount
	var multiplier := 1.0
	if spec != null:
		var skill_amount := spec.get_set_by_caller_magnitude(GameplayTags.Data_SkillMagnitude, -1.0)
		var trigger_amount := spec.get_set_by_caller_magnitude(GameplayTags.Data_TriggerMagnitude, -1.0)
		if skill_amount >= 0.0:
			amount = skill_amount
		elif trigger_amount >= 0.0:
			amount = trigger_amount
		multiplier = CritResolution.multiplier(spec)

	return floorf(amount * multiplier)


func status_display_name() -> String:
	return StatusText.display_name(attribute_name)
