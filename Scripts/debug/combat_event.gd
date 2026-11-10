## 调试事件分类与公共字段构造。
##
## 事件本身用 Dictionary 存，方便直接写 JSONL；这里只放常量和
## “单位 → 可序列化字段”的转换，避免把 Node 引用写进事件缓冲。
class_name CombatEvent extends RefCounted

## 分类与重要度沿用模拟层事件总线的词表，保证两边字符串永远一致。

## 重要事件：默认显示在时间线
const IMPORTANT: String = BattleEvent.IMPORTANCE_IMPORTANT
## 详细事件：只在关注单位或打开详细模式时记录
const DETAIL: String = BattleEvent.IMPORTANCE_DETAIL

const BATTLE: String = BattleEvent.CATEGORY_BATTLE
const CAST: String = BattleEvent.CATEGORY_CAST
const SOUL: String = BattleEvent.CATEGORY_SOUL
const TRIGGER: String = BattleEvent.CATEGORY_TRIGGER
const EFFECT: String = BattleEvent.CATEGORY_EFFECT
const ATTRIBUTE: String = BattleEvent.CATEGORY_ATTRIBUTE
const TAG: String = BattleEvent.CATEGORY_TAG
const CUE: String = BattleEvent.CATEGORY_CUE
const LOG: String = BattleEvent.CATEGORY_LOG
const SYSTEM: String = BattleEvent.CATEGORY_SYSTEM

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
