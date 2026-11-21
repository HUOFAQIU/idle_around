extends Node

const SCAN_DIRS: Array[String] = [
	"res://Scripts",
	"res://Main",
	"res://game",
	"res://godot_gas",
	"res://Windows",
	"res://EngineTools/modkit",
	"res://tools/scenarios",
]


func _ready() -> void:
	var files: Array[String] = []
	for dir_path in SCAN_DIRS:
		_collect(dir_path, files)

	var failed: int = 0
	for path in files:
		if ResourceLoader.load(path) == null:
			failed += 1
			print("CHECK_FAIL ", path)

	print("CHECK_TOTAL ", files.size())
	print("CHECK_FAILED ", failed)
	get_tree().quit(0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				_collect(full, out)
			elif entry.ends_with(".gd") or entry.ends_with(".tscn") or entry.ends_with(".tres"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
