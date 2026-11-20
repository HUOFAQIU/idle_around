extends RefCounted
## 命令补全候选来源：只枚举现有数据，不写业务。
##
## 加候选：在这里写静态方法，再在 command_catalog.gd 的 complete 数组里登记。

const INVENTORY: GDScript = preload("res://Scripts/test_api/inventory.gd")
const MAP: GDScript = preload("res://Scripts/test_api/map.gd")
const CHARACTER_CATALOG: GDScript = preload(
		"res://game/content/Characters/character_catalog.gd")
const MAP_BOARD: GDScript = preload("res://Scripts/map_board.gd")
const SAVE_STORAGE: GDScript = preload("res://Scripts/save/save_storage.gd")


static func soul_ids() -> PackedStringArray:
	return _to_packed(INVENTORY.get_soul_ids())


static func container_names() -> PackedStringArray:
	return INVENTORY.get_container_names()


static func monster_ids() -> PackedStringArray:
	return _to_packed(INVENTORY.get_monster_ids())


static func map_ids() -> PackedStringArray:
	return _to_packed(MAP.get_map_ids())


static func character_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for character in CHARACTER_CATALOG.all():
		if character != null:
			result.append(String(character.id))
	return result


static func map_slots() -> PackedStringArray:
	return _number_range(MAP_BOARD.SLOT_COUNT)


static func save_slots() -> PackedStringArray:
	return _number_range(SAVE_STORAGE.SLOT_COUNT)


static func damage_targets() -> PackedStringArray:
	return PackedStringArray(["enemy", "player"])


static func _number_range(count: int) -> PackedStringArray:
	var result := PackedStringArray()
	for index in count:
		result.append(str(index))
	return result


static func _to_packed(values: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for value in values:
		result.append(String(value))
	return result
