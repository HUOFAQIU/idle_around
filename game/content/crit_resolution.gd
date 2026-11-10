class_name CritResolution extends RefCounted
## 执行器共用的暴击解析。
##
## 暴击倍率由 AutoCastAbility 通过 spec 的 SetByCaller 写入；
## 直接伤害/治疗/护盾暴击时统一注入 Event.Combat.Critical。


## 读取本次释放的暴击倍率；未注入时返回 1.0。
static func multiplier(spec: GameplayEffectSpec) -> float:
	if spec == null:
		return 1.0
	return maxf(spec.get_set_by_caller_magnitude(GameplayTags.Data_CritMultiplier, 1.0), 0.0)


## 倍率 > 1.0 时注入暴击标签。
static func inject_if_critical(spec: GameplayEffectSpec, crit_multiplier: float) -> void:
	if crit_multiplier > 1.0 and spec != null:
		spec.inject_tag(GameplayTags.Event_Combat_Critical)
