class_name CritResolution extends RefCounted


static func multiplier(spec: GameplayEffectSpec) -> float:
	if spec == null:
		return 1.0
	return maxf(spec.get_set_by_caller_magnitude(GameplayTags.Data_CritMultiplier, 1.0), 0.0)


static func inject_if_critical(spec: GameplayEffectSpec, crit_multiplier: float) -> void:
	if crit_multiplier > 1.0 and spec != null:
		spec.inject_tag(GameplayTags.Event_Combat_Critical)
