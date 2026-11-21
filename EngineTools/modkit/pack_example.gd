extends SceneTree

const MOD_ID: String = "example_souls"
const MOD_SOURCE: String = "res://mods/" + MOD_ID
const INSTALL_DIR: String = "user://mods/" + MOD_ID
const MANIFEST_FILE: String = "mod.json"
const PACK_FILE: String = "content.pck"


func _init() -> void:
	quit(_pack_example())


func _pack_example() -> int:
	if DirAccess.open(MOD_SOURCE) == null:
		push_error("找不到示例 mod 源码：%s" % MOD_SOURCE)
		return 1
	var install_path := ProjectSettings.globalize_path(INSTALL_DIR)
	var err := DirAccess.make_dir_recursive_absolute(install_path)
	if err != OK:
		push_error("创建安装目录失败：%s（%d）" % [install_path, err])
		return 1

	var pck_path := install_path.path_join(PACK_FILE)
	if FileAccess.file_exists(pck_path):
		DirAccess.remove_absolute(pck_path)
	var packer := PCKPacker.new()
	err = packer.pck_start(pck_path)
	if err != OK:
		push_error("创建 PCK 失败：%s（%d）" % [pck_path, err])
		return 1

	var files := _collect_files(MOD_SOURCE)
	var added := 0
	for source_path in files:
		var relative := source_path.trim_prefix(MOD_SOURCE + "/")
		if relative == MANIFEST_FILE:
			continue
		var target_path := "res://mods/%s/%s" % [MOD_ID, relative]
		err = packer.add_file(target_path, source_path)
		if err != OK:
			push_error("打包失败：%s（%d）" % [source_path, err])
			return 1
		added += 1
	err = packer.flush()
	if err != OK:
		push_error("写入 PCK 失败：%s（%d）" % [pck_path, err])
		return 1

	var manifest_target := ProjectSettings.globalize_path(INSTALL_DIR.path_join(MANIFEST_FILE))
	if FileAccess.file_exists(manifest_target):
		DirAccess.remove_absolute(manifest_target)
	err = DirAccess.copy_absolute(
		ProjectSettings.globalize_path(MOD_SOURCE.path_join(MANIFEST_FILE)),
		manifest_target
	)
	if err != OK:
		push_error("复制 mod.json 失败：%s（%d）" % [manifest_target, err])
		return 1

	print("示例 mod 已打包：%s（%d 个文件）" % [pck_path, added])
	print("mod.json：%s" % manifest_target)
	return 0


func _collect_files(path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not file_name.begins_with("."):
			var full_path := path.path_join(file_name)
			if dir.current_is_dir():
				result.append_array(_collect_files(full_path))
			else:
				result.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result
