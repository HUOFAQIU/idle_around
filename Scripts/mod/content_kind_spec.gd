## 内容种类的规格表：manifest 键、ID/路径字段、后缀、core 目录与文件后缀。
##
## ModLoader 与 CoreContentValidator 都按这张表遍历，新增一种内容只改这里和
## ModLoader 的类型注册分支。返回 Dictionary 而不是自定义类型，保证 modkit 的
## `--script` 模式（没有全局类缓存）也能通过 preload 使用。
class_name ContentKindSpec extends RefCounted

const CONTENT_KIND: GDScript = preload("res://Scripts/mod/content_kind.gd")


static func all() -> Array[Dictionary]:
	return [
		{
			"kind": CONTENT_KIND.Kind.SOUL,
			"key": "souls",
			"label": "魂灵",
			"id_field": "id",
			"path_field": "path",
			"id_suffix": "_soul",
			"legacy_suffix": "",
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
			"legacy_suffix": "_data",
			"is_tag": false,
			"core_dir": "monsters",
			"core_suffixes": ["_monster.tres", "_data.tres"],
		},
		{
			"kind": CONTENT_KIND.Kind.CUE,
			"key": "cues",
			"label": "Cue",
			"id_field": "tag",
			"path_field": "scene",
			"id_suffix": "",
			"legacy_suffix": "",
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
