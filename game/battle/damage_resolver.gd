class_name DamageResolver extends RefCounted

static func split_damage(
	target_asc: AbilitySystemComponent,
	damage: float,
	shield_factor: float = 1.0
) -> Dictionary:
	var result: Dictionary = {}
	var total_damage := floorf(maxf(damage, 0.0))
	if target_asc == null or total_damage <= 0.0:
		return result

	var shield_attr := target_asc.get_attribute("shield")
	var shield_value := floorf(maxf(shield_attr.current_value, 0.0)) if shield_attr != null else 0.0
	var shield_loss := 0.0
	var health_loss := total_damage

	if shield_value > 0.0:
		if shield_factor >= 1.0:
			shield_loss = minf(shield_value, total_damage)
			health_loss = total_damage - shield_loss
		else:
			var shield_damage := floorf(total_damage * shield_factor)
			shield_loss = minf(shield_value, shield_damage)
			if shield_loss >= shield_value:
				health_loss = maxf(total_damage - shield_value * 2.0, 0.0)
			else:
				health_loss = 0.0

	if shield_loss > 0.0:
		result["shield"] = -shield_loss
	if health_loss > 0.0:
		result["health"] = -health_loss
	return result
