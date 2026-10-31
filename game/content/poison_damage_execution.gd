## 伤害 + 剧毒的 execution。
##
## 先按 SoulDamageExecution 计算最终伤害并分流到护盾/生命，
## 再把“最终伤害 × poison_ratio”写成剧毒值。剧毒本身的周期结算不再暴击。
class_name PoisonDamageExecution extends SoulDamageExecution

## 伤害转化为剧毒的比例；1 = 等量（吹箭），0.1 = 伤害的 10%（毒牙）
@export_range(0.0, 1.0, 0.01) var poison_ratio: float = 1.0


func execute(spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var result := super.execute(spec, target_asc)
	if result.is_empty():
		return result

	# SoulDamageExecution 返回的是负的 shield/health；两者绝对值之和就是最终伤害。
	var damage := -float(result.get("health", 0.0)) - float(result.get("shield", 0.0))
	# 剧毒按整数结算；换算后不足 1 点时保底 1 点
	var poison_amount := 0.0
	if damage > 0.0 and poison_ratio > 0.0:
		poison_amount = maxf(floorf(damage * poison_ratio), 1.0)
	if poison_amount > 0.0:
		result["poison"] = poison_amount
	return result
