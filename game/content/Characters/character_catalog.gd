class_name CharacterCatalog
extends RefCounted
## 角色目录：角色选择面和开局流程共用这份静态列表。
##
## 新增角色时在 base_mods/内容层加 CharacterDefinition 资源，并登记到这里；
## 存档找不到对应 id 时由 GameFlow 回退到默认角色。

const SMALL_COAL_LAMP: CharacterDefinition = preload(
		"res://game/content/Characters/characters/small_coal_lamp.tres")


static func all() -> Array[CharacterDefinition]:
	var result: Array[CharacterDefinition] = [SMALL_COAL_LAMP]
	return result


static func get_by_id(character_id: StringName) -> CharacterDefinition:
	for character in all():
		if character.id == character_id:
			return character
	return null


static func default_character() -> CharacterDefinition:
	return SMALL_COAL_LAMP
