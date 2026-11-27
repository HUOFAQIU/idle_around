extends SceneTree

const CONTAINER_IDS: GDScript = preload("res://scripts/container_ids.gd")


func _init() -> void:
	var errors := _validate()
	if errors.is_empty():
		print("容器名校验通过。")
		quit(0)
		return
	for message in errors:
		printerr("container ids: " + message)
	quit(1)


func _validate() -> Array[String]:
	var errors: Array[String] = []
	var vessel_names: Array[String] = [CONTAINER_IDS.VESSEL_GRID]
	_check_scene(
		"res://windows/Character/character_window.tscn",
		vessel_names,
		errors
	)
	var inventory_names: Array[String] = [CONTAINER_IDS.MAIN_INVENTORY]
	_check_scene(
		"res://windows/Inventory/inventory_window.tscn",
		inventory_names,
		errors
	)
	var shop_names: Array[String] = [CONTAINER_IDS.SHOP]
	_check_scene(
		"res://windows/Shop/shop_window.tscn",
		shop_names,
		errors
	)
	return errors


func _check_scene(path: String, expected: Array[String], errors: Array[String]) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("场景读取失败：%s" % path)
		return
	var actual: Array[String] = []
	var regex := RegEx.create_from_string("(?m)^\\s*container_name = \"([^\"]+)\"")
	for found in regex.search_all(text):
		actual.append(found.get_string(1))
	if actual != expected:
		errors.append("%s 的 container_name 应为 %s，实际为 %s" % [path, expected, actual])
