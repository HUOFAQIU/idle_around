class_name ContentKindSpec extends RefCounted

const CONTENT_KIND: GDScript = preload("res://scripts/mod/content_kind.gd")


static func all() -> Array[Dictionary]:
	return [
		{
			"kind": CONTENT_KIND.Kind.SOUL,
			"key": "souls",
			"label": "魂灵",
			"id_field": "id",
			"path_field": "path",
			"id_suffix": "_soul",
			"is_tag": false,
			"core_dir": "souls",
			"core_suffixes": ["_soul.tres"],
		},
		{
			"kind": CONTENT_KIND.Kind.MONSTER,
			"key": "monsters",
			"label": "怪物",
			"id_field": "id",
			"path_field": "path",
			"id_suffix": "_monster",
			"is_tag": false,
			"core_dir": "monsters",
			"core_suffixes": ["_monster.tres"],
		},
		{
			"kind": CONTENT_KIND.Kind.VESSEL,
			"key": "vessels",
			"label": "魂器",
			"id_field": "id",
			"path_field": "path",
			"id_suffix": "_vessel",
			"is_tag": false,
			"core_dir": "vessels",
			"core_suffixes": ["_vessel.tres"],
		},
		{
			"kind": CONTENT_KIND.Kind.CUE,
			"key": "cues",
			"label": "Cue",
			"id_field": "tag",
			"path_field": "scene",
			"id_suffix": "",
			"is_tag": true,
			"core_dir": "cues",
			"core_suffixes": [".tscn"],
		},
	]


static func for_key(key: String) -> Dictionary:
	for spec in all():
		if String(spec.get("key", "")) == key:
			return spec
	return {}
