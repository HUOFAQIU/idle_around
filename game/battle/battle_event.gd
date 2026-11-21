class_name BattleEvent extends RefCounted

const CATEGORY_BATTLE: String = "battle"
const CATEGORY_CAST: String = "cast"
const CATEGORY_SOUL: String = "soul"
const CATEGORY_TRIGGER: String = "trigger"
const CATEGORY_EFFECT: String = "effect"
const CATEGORY_ATTRIBUTE: String = "attribute"
const CATEGORY_TAG: String = "tag"
const CATEGORY_CUE: String = "cue"
const CATEGORY_LOG: String = "log"
const CATEGORY_SYSTEM: String = "system"

const IMPORTANCE_IMPORTANT: String = "important"
const IMPORTANCE_DETAIL: String = "detail"

var category: String = ""
var type: String = ""
var fields: Dictionary = {}
var importance: String = IMPORTANCE_IMPORTANT


func _init(
	p_category: String,
	p_type: String,
	p_fields: Dictionary = {},
	p_importance: String = IMPORTANCE_IMPORTANT
) -> void:
	category = p_category
	type = p_type
	fields = p_fields
	importance = p_importance
