class_name SaveDocument extends RefCounted

const VERSION: int = 2

const KEY_VERSION: String = "version"
const KEY_SAVED_AT: String = "saved_at_unix"
const KEY_PLAY_TIME: String = "play_time_sec"
const KEY_PLAYER: String = "player"
const KEY_CONTAINERS: String = "containers"
const KEY_DETACHED: String = "detached"
const KEY_COLLECTION: String = "collection"
const KEY_MAP_BOARD: String = "map_board"
const KEY_ORPHANED: String = "orphaned"

const DEFAULT_CHARACTER_ID: StringName = &"small_coal_lamp"
const DEFAULT_CHARACTER_NAME: String = "小煤灯"


static func empty() -> Dictionary:
	return {
		KEY_VERSION: VERSION,
		KEY_SAVED_AT: int(Time.get_unix_time_from_system()),
		KEY_PLAY_TIME: 0.0,
		KEY_PLAYER: {},
		KEY_CONTAINERS: {},
		KEY_DETACHED: [],
		KEY_COLLECTION: {"souls": [], "monsters": []},
		KEY_MAP_BOARD: {"slots": [], "pending": null},
	}


static func build(play_time_sec: float, player_data: Dictionary = {}) -> Dictionary:
	var document := empty()
	document[KEY_PLAY_TIME] = play_time_sec
	document[KEY_PLAYER] = player_data.duplicate(true)
	return document


static func version_of(document: Dictionary) -> int:
	return int(document.get(KEY_VERSION, 0))


static func player_of(document: Dictionary) -> Dictionary:
	var raw: Variant = document.get(KEY_PLAYER, {})
	if raw is Dictionary:
		var player := raw as Dictionary
		if not player.is_empty():
			return player.duplicate(true)
	return {
		"character_id": DEFAULT_CHARACTER_ID,
		"display_name": DEFAULT_CHARACTER_NAME,
	}

