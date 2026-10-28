## 伤害分流：先扣护盾，再扣生命。
##
## 普通伤害：1 点护盾吸收 1 点伤害，护盾不够的部分进生命。
## 灼烧：对护盾伤害减半并向下取整，1 点护盾吸收 2 点灼烧伤害；
##       护盾没破时不伤生命，护盾破了才把剩余灼烧伤害打进生命。
class_name DamageResolver extends RefCounted

## shield_factor = 1.0：普通伤害；0.5：灼烧。
static func split_damage(
	target_asc: AbilitySystemComponent,
	damage: float,
	shield_factor: float = 1.0
) -> Dictionary:
	var result: Dictionary = {}
	if target_asc == null or damage <= 0.0:
		return result

	var shield_attr := target_asc.get_attribute("shield")
	var shield_value := maxf(shield_attr.current_value, 0.0) if shield_attr != null else 0.0
	var shield_loss := 0.0
	var health_loss := damage

	if shield_value > 0.0:
		if shield_factor >= 1.0:
			shield_loss = minf(shield_value, damage)
			health_loss = damage - shield_loss
		else:
			# 灼烧：先减半并向下取整，得到护盾实际承受的伤害。
			var shield_damage := float(int(floor(damage * shield_factor)))
			shield_loss = minf(shield_value, shield_damage)
			if shield_loss >= shield_value:
				# 护盾被打穿：每 1 点护盾抵消 2 点灼烧，剩余部分进生命。
				health_loss = maxf(damage - shield_value * 2.0, 0.0)
			else:
				# 护盾还活着：这一跳不伤生命。
				health_loss = 0.0

	if shield_loss > 0.0:
		result["shield"] = -shield_loss
	if health_loss > 0.0:
		result["health"] = -health_loss
	return result
