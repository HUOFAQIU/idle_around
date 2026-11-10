## 战斗事件：模拟层发给观察层的一条结构化记录。
##
## fields 里可以带 BattleUnit / GameplayEffectSpec / CombatTrace 等运行时引用，
## 由订阅方在自己的出口转换；事件本身不参与任何战斗判定。
## 分类与重要度字符串是调试遥测 JSONL schema 的一部分，不要随意改名。
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

## 重要事件：默认显示在时间线
const IMPORTANCE_IMPORTANT: String = "important"
## 详细事件：只记录关注单位或打开详细模式时
const IMPORTANCE_DETAIL: String = "detail"

## 事件分类，取 CATEGORY_* 之一
var category: String = ""
## 事件类型；具体取值由分类决定，调试窗口负责翻译成中文
var type: String = ""
## 事件字段；允许运行时引用，订阅方不得修改
var fields: Dictionary = {}
## 重要度，取 IMPORTANCE_* 之一
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
