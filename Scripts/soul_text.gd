class_name SoulText
extends RefCounted

const SIZE_NAMES := {
	&"Soul.tags.Small": "小型",
	&"Soul.tags.Medium": "中型",
	&"Soul.tags.Large": "大型",
}

const TYPE_NAMES := {
	&"Soul.types.Wolf": "狼",
	&"Soul.types.Animal": "动物",
}


static func size_name(size_tag: StringName) -> String:
	return SIZE_NAMES.get(size_tag, String(size_tag))


static func type_name(type: StringName) -> String:
	var text := String(type)
	return TYPE_NAMES.get(type, text.get_slice(".", 2))
