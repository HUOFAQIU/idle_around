class_name CharacterCatalog
extends RefCounted

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
