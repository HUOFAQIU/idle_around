class_name SoulEmotionRoller
extends RefCounted


static func roll(soul: SoulData, rarity: int, rng: RandomNumberGenerator) -> void:
	if soul == null:
		return
	soul.emotions.clear()
	if soul.emotion_ranges.is_empty():
		return
	var declared := SoulEmotion.effective_ids(soul.emotion_ranges)
	var effective := declared
	if effective.size() > SoulEmotion.MAX_TYPES:
		effective = _pick(declared, SoulEmotion.MAX_TYPES, rng)
	var junk_pool := SoulEmotion.junk_ids(declared)
	var junk_count := mini(SoulEmotion.MAX_TYPES - effective.size(), junk_pool.size())
	var junk := _pick(junk_pool, junk_count, rng)

	var total := 0
	if effective.is_empty():
		total = 0
	elif junk.is_empty():
		total = 100
	else:
		var bounds := SoulEmotion.total_range(rarity)
		total = rng.randi_range(bounds.x, bounds.y)

	var effective_shares := _split(total, effective.size(), rng)
	for i in effective.size():
		soul.emotions[effective[i]] = effective_shares[i]
	var junk_shares := _split(100 - total, junk.size(), rng)
	for i in junk.size():
		soul.emotions[junk[i]] = junk_shares[i]


static func _pick(
	source: Array[StringName], count: int, rng: RandomNumberGenerator
) -> Array[StringName]:
	var pool: Array[StringName] = source.duplicate()
	var result: Array[StringName] = []
	for _index in mini(count, pool.size()):
		var at := rng.randi_range(0, pool.size() - 1)
		result.append(pool[at])
		pool.remove_at(at)
	return result


static func _split(total: int, count: int, rng: RandomNumberGenerator) -> Array[int]:
	var result: Array[int] = []
	if count <= 0:
		return result
	for _index in count:
		result.append(1)
	var remainder := total - count
	while remainder > 0:
		var at := rng.randi_range(0, count - 1)
		var add := rng.randi_range(1, remainder)
		result[at] += add
		remainder -= add
	return result
