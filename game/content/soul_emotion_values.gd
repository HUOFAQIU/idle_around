class_name SoulEmotionValues
extends RefCounted

const TICKS_PER_SECOND: float = 120.0


static func declared(soul: SoulData, id: StringName) -> bool:
	return soul != null and SoulEmotion.dict_get(soul.emotion_ranges, id, null) is Vector2


static func share(soul: SoulData, id: StringName) -> int:
	if soul == null:
		return 0
	return int(SoulEmotion.dict_get(soul.emotions, id, 0))


static func is_effective(soul: SoulData, id: StringName) -> bool:
	return soul != null and SoulEmotion.is_effective(soul.emotion_ranges, id)


static func value(soul: SoulData, id: StringName) -> float:
	if soul == null:
		return 0.0
	var bounds: Variant = SoulEmotion.dict_get(soul.emotion_ranges, id, null)
	if not bounds is Vector2:
		return 0.0
	var span := bounds as Vector2
	return span.x + (span.y - span.x) * float(share(soul, id)) / 100.0


static func damage_base(soul: SoulData) -> float:
	if not declared(soul, SoulEmotion.DAMAGE):
		return -1.0
	return floorf(value(soul, SoulEmotion.DAMAGE))


static func cooldown_seconds(soul: SoulData) -> float:
	if not declared(soul, SoulEmotion.COOLDOWN):
		return -1.0
	return roundi(value(soul, SoulEmotion.COOLDOWN) * TICKS_PER_SECOND) / TICKS_PER_SECOND


static func cast_times(soul: SoulData) -> int:
	if not declared(soul, SoulEmotion.CAST_TIMES):
		return 0
	var span := SoulEmotion.dict_get(
		soul.emotion_ranges, SoulEmotion.CAST_TIMES, Vector2.ZERO
	) as Vector2
	var low := roundi(span.x)
	var high := roundi(span.y)
	if high <= low:
		return maxi(low, 1)
	var steps := high - low
	var ratio := float(share(soul, SoulEmotion.CAST_TIMES)) / 100.0
	var index := mini(int(floorf(ratio * float(steps) + 0.0001)), steps)
	return low + index
