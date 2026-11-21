class_name CombatTelemetrySchema extends RefCounted


const IMPORTANT: String = BattleEvent.IMPORTANCE_IMPORTANT
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
