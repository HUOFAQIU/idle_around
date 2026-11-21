class_name StatusText extends RefCounted

const NAMES := {
	"burn": "灼烧",
	"poison": "剧毒",
	"regen": "生命再生",
}


static func display_name(attribute_name: String) -> String:
	return NAMES.get(attribute_name, attribute_name)


static func log_color(attribute_name: String) -> String:
	match attribute_name:
		"burn":
			return GameColors.BURN
		"poison":
			return GameColors.POISON
		"regen":
			return GameColors.REGEN
		_:
			return GameColors.TEXT_PRIMARY
