class_name SoulEmotion
extends RefCounted

const COOLDOWN: StringName = &"cooldown"
const CAST_TIMES: StringName = &"cast_times"
const DAMAGE: StringName = &"damage"

const IDS: Array[StringName] = [
	&"cooldown",
	&"charge",
	&"haste",
	&"slow",
	&"sluggish",
	&"swift",
	&"freeze",
	&"damage",
	&"burn",
	&"poison",
	&"shield",
	&"heal",
	&"regen",
	&"cast_times",
	&"max_health",
	&"crit_chance",
]

const NAMES := {
	&"cooldown": "冷却",
	&"charge": "充能",
	&"haste": "加速",
	&"slow": "减速",
	&"sluggish": "迟缓",
	&"swift": "迅捷",
	&"freeze": "冻结",
	&"damage": "伤害",
	&"burn": "灼烧",
	&"poison": "剧毒",
	&"shield": "护盾",
	&"heal": "治疗",
	&"regen": "生命再生",
	&"cast_times": "多重触发",
	&"max_health": "最大生命值",
	&"crit_chance": "增加暴击率",
}

const RARITY_NAMES := {
	1: "普通",
	2: "精良",
	3: "稀有",
	4: "史诗",
	5: "传说",
}

const RARITY_TOTALS := {
	1: Vector2i(20, 35),
	2: Vector2i(30, 45),
	3: Vector2i(40, 55),
	4: Vector2i(50, 70),
	5: Vector2i(65, 85),
}

const MAX_TYPES: int = 6
const DEFAULT_RARITY: int = 3


static func display_name(id: StringName) -> String:
	return String(NAMES.get(id, String(id)))


static func rarity_name(rarity: int) -> String:
	return String(RARITY_NAMES.get(clampi(rarity, 1, 5), RARITY_NAMES[DEFAULT_RARITY]))


static func total_range(rarity: int) -> Vector2i:
	return RARITY_TOTALS.get(clampi(rarity, 1, 5), RARITY_TOTALS[DEFAULT_RARITY])


static func is_valid(id: StringName) -> bool:
	return IDS.has(id)


static func dict_get(source: Dictionary, id: StringName, fallback: Variant) -> Variant:
	if source.has(id):
		return source[id]
	var text := String(id)
	if source.has(text):
		return source[text]
	return fallback


static func is_effective(ranges: Dictionary, id: StringName) -> bool:
	return id != COOLDOWN and dict_get(ranges, id, null) is Vector2


static func effective_ids(ranges: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for id in IDS:
		if is_effective(ranges, id):
			result.append(id)
	return result


static func junk_ids(effective: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for id in IDS:
		if not effective.has(id):
			result.append(id)
	return result


static func ordered_ids(source: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for id in IDS:
		if dict_get(source, id, null) != null:
			result.append(id)
	var extra: Array[String] = []
	for key in source:
		var id := StringName(String(key))
		if not IDS.has(id):
			extra.append(String(id))
	extra.sort()
	for text in extra:
		result.append(StringName(text))
	return result
