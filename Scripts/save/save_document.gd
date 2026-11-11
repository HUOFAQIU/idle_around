## 存档顶层文档：版本号、公共字段与 section 键的唯一来源。
##
## participant 只读写自己负责的 section；顶层键和迁移入口都集中在这里，
## 避免 collect / empty 各写一份 schema。
class_name SaveDocument extends RefCounted

const VERSION: int = 1

const KEY_VERSION: String = "version"
const KEY_SAVED_AT: String = "saved_at_unix"
const KEY_PLAY_TIME: String = "play_time_sec"
const KEY_CONTAINERS: String = "containers"
const KEY_DETACHED: String = "detached"
const KEY_COLLECTION: String = "collection"
const KEY_ORPHANED: String = "orphaned"


## 新档/无存档时的完整默认文档
static func empty() -> Dictionary:
	return {
		KEY_VERSION: VERSION,
		KEY_SAVED_AT: int(Time.get_unix_time_from_system()),
		KEY_PLAY_TIME: 0.0,
		KEY_CONTAINERS: {},
		KEY_DETACHED: [],
		KEY_COLLECTION: {"souls": [], "monsters": []},
	}


## 写档前建文档；participant 随后往里面填自己的 section
static func build(play_time_sec: float) -> Dictionary:
	var document := empty()
	document[KEY_PLAY_TIME] = play_time_sec
	return document


static func version_of(document: Dictionary) -> int:
	return int(document.get(KEY_VERSION, 0))


## 版本迁移入口：结构变化时按 from_version 逐级转换；当前只有 v1
static func migrate(document: Dictionary, _from_version: int) -> Dictionary:
	document[KEY_VERSION] = VERSION
	return document
