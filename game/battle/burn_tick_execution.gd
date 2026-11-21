class_name BurnTickExecution extends PeriodicStatusTickExecution

## 每层灼烧每跳的伤害
@export var damage_per_stack: float = 1.0
## 每跳衰减比例；当前层数 ×(1 - decay_rate) 后向下取整
@export_range(0.0, 1.0, 0.01) var decay_rate: float = 0.03


func status_attribute() -> String:
	return "burn"


func remove_when_zero() -> bool:
	return true


func popup_style() -> PopupStyle:
	return PopupStyle.BURN


func execute(_spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var burn_attr := target_asc.get_attribute("burn") if target_asc != null else null
	if burn_attr == null:
		return {}

	var stacks := floori(maxf(burn_attr.current_value, 0.0))
	if stacks <= 0:
		return {}

	var damage := stacks * damage_per_stack
	var next_stacks := floori(float(stacks) * (1.0 - decay_rate))

	var result := DamageResolver.split_damage(target_asc, damage, 0.5)
	result["burn"] = float(next_stacks - stacks)
	return result
