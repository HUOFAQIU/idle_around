class_name SoulText
extends RefCounted
## 魂灵相关固定显示名（尺寸、类型），tooltip / 见闻 / 调试共用。

const SIZE_NAMES := {
	&"Soul.tags.Small": "小型",
	&"Soul.tags.Medium": "中型",
	&"Soul.tags.Large": "大型",
}

const TYPE_NAMES := {
	&"Soul.types.Wolf": "狼",
	&"Soul.types.Animal": "动物",
}


## 尺寸标签 → 中文名；未知值原样返回
static func size_name(size_tag: StringName) -> String:
	return SIZE_NAMES.get(size_tag, String(size_tag))


## 类型 ID → 中文名；未知类型回退到 ID 最后一段
static func type_name(type: StringName) -> String:
	var text := String(type)
	return TYPE_NAMES.get(type, text.get_slice(".", 2))
