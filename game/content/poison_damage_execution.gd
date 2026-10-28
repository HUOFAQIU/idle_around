## 伤害 + 剧毒的 execution。
##
## 先按 SoulDamageExecution 计算最终伤害并分流到护盾/生命，
## 再把“最终伤害”等量写成剧毒值。剧毒本身的周期结算不再暴击。
class_name PoisonDamageExecution extends SoulDamageExecution


func execute(spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var result := super.execute(spec, target_asc)
	if result.is_empty():
		return result

	# SoulDamageExecution 返回的是负的 shield/health；两者绝对值之和就是最终伤害。
	var damage := -float(result.get("health", 0.0)) - float(result.get("shield", 0.0))
	if damage > 0.0:
		result["poison"] = damage
	return result
