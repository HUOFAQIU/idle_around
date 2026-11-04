class_name SoulText
extends RefCounted
## 魂灵相关固定显示名（部位、类型），tooltip / 见闻 / 调试共用。

const PART_NAMES := {
	"ANY": "不限部位",
	"HEADSOUL": "头部",
	"TORSOSOUL": "身体",
	"ARMSSOUL": "手部",
	"LEGSSOUL": "腿部",
}

const TYPE_NAMES := {
	&"Soul.types.Wolf": "狼",
	&"Soul.types.Animal": "动物",
}


## 部位枚举值 → 中文名；未知值原样返回
static func part_name(part: String) -> String:
	return PART_NAMES.get(part, part)


## 类型 ID → 中文名；未知类型回退到 ID 最后一段
static func type_name(type: StringName) -> String:
	var text := String(type)
	return TYPE_NAMES.get(type, text.get_slice(".", 2))
