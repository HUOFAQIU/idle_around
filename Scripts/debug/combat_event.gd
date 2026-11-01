## 调试事件分类与公共字段构造。
##
## 事件本身用 Dictionary 存，方便直接写 JSONL；这里只放常量和
## “单位 → 可序列化字段”的转换，避免把 Node 引用写进事件缓冲。
class_name CombatEvent extends RefCounted

## 重要事件：默认显示在时间线
const IMPORTANT: String = "important"
## 详细事件：只在关注单位或打开详细模式时记录
const DETAIL: String = "detail"

const BATTLE: String = "battle"
const CAST: String = "cast"
const SOUL: String = "soul"
const TRIGGER: String = "trigger"
const EFFECT: String = "effect"
const ATTRIBUTE: String = "attribute"
const TAG: String = "tag"
const CUE: String = "cue"
const LOG: String = "log"
const SYSTEM: String = "system"

const CATEGORY_COLORS := {
	BATTLE: "#ffd866",
	CAST: "#6fb7ff",
	SOUL: "#8cd9ff",
	TRIGGER: "#c792ea",
	EFFECT: "#57d9e8",
	ATTRIBUTE: "#f0f0f0",
	TAG: "#9aa7b0",
	CUE: "#ff9f43",
	LOG: "#d0d0d0",
	SYSTEM: "#ff6e6e",
}


## 单位 → 事件字段；已释放的单位返回空字典
static func unit_info(unit: Variant) -> Dictionary:
	if unit == null or not is_instance_valid(unit):
		return {}
	return {
		"id": unit.get_instance_id(),
		"name": String(unit.get("unit_name")),
		"team": team_name(int(unit.get("team"))),
	}


static func team_name(team_id: int) -> String:
	return "PLAYER" if team_id == 0 else "ENEMY"


static func category_color(category: String) -> String:
	return CATEGORY_COLORS.get(category, "#ffffff")
