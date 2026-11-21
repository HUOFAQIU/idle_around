class_name PoisonDamageExecution extends SoulDamageExecution

## 伤害转化为剧毒的比例；1 = 等量（吹箭），0.1 = 伤害的 10%（毒牙）
@export_range(0.0, 1.0, 0.01) var poison_ratio: float = 1.0


func execute(spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var result := super.execute(spec, target_asc)
	if result.is_empty():
		return result

	var damage := -float(result.get("health", 0.0)) - float(result.get("shield", 0.0))
	var poison_amount := 0.0
	if damage > 0.0 and poison_ratio > 0.0:
		poison_amount = maxf(floorf(damage * poison_ratio), 1.0)
	if poison_amount > 0.0:
		result["poison"] = poison_amount
	return result
