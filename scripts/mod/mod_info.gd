class_name ModInfo
extends RefCounted

enum Source {
	LOCAL,
	WORKSHOP,
	BUILTIN,
}

var id: StringName = &""
var name: String = ""
var version: String = "0.0.0"
var author: String = ""
var description: String = ""
var source: Source = Source.LOCAL
var root_path: String = ""
var manifest_path: String = ""
var pack_path: String = ""
var manifest: ModManifest
var enabled: bool = true
var blocked: bool = false
var loaded: bool = false
var mounted: bool = false
var soul_count: int = 0
var monster_count: int = 0
var vessel_count: int = 0
var cue_count: int = 0
var map_count: int = 0
var item_count: int = 0
var errors: Array[String] = []
var warnings: Array[String] = []


func is_builtin() -> bool:
	return source == Source.BUILTIN
