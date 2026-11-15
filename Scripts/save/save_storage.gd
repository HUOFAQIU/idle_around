## 多槽存档的磁盘读写：临时文件 + 备份轮换 + 只读态。
##
## 只认 JSON 字典与版本号是否存在，不解释业务 section；
## 业务数据由 SaveDocument 与 participant 负责。
class_name SaveStorage extends RefCounted

const SAVE_DIR: String = "user://saves"
const SLOT_COUNT: int = 6

var _read_only: bool = false


static func slot_file(slot: int) -> String:
	return "slot_%d.json" % slot


static func slot_path(slot: int) -> String:
	return SAVE_DIR + "/" + slot_file(slot)


static func backup_path(slot: int) -> String:
	return slot_path(slot) + ".bak"


static func temp_path(slot: int) -> String:
	return slot_path(slot) + ".tmp"


static func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT


func read_primary(slot: int) -> Dictionary:
	if not is_valid_slot(slot):
		return {}
	return _read(slot_path(slot))


func read_backup(slot: int) -> Dictionary:
	if not is_valid_slot(slot):
		return {}
	return _read(backup_path(slot))


## 原子写：先写临时文件，再轮换主文件/备份
func write(slot: int, data: Dictionary, keep_backup: bool = false) -> bool:
	if not is_valid_slot(slot):
		return false
	if not _ensure_save_dir():
		return false
	var file_name := slot_file(slot)
	var backup_name := file_name + ".bak"
	var temp_name := file_name + ".tmp"
	var temp_file_path := SAVE_DIR + "/" + temp_name
	var file := FileAccess.open(temp_file_path, FileAccess.WRITE)
	if file == null:
		push_warning("存档：无法写入临时文件 %s（%s）" % [temp_file_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()

	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		push_warning("存档：无法打开目录 %s" % SAVE_DIR)
		return false
	if dir.file_exists(file_name):
		if keep_backup:
			# 主文件已经损坏；只替换主文件，保留刚恢复用的好备份
			var remove_err := dir.remove(file_name)
			if remove_err != OK:
				push_warning("存档：无法移除损坏的主存档（%s）" % error_string(remove_err))
				dir.remove(temp_name)
				return false
		else:
			if dir.file_exists(backup_name):
				dir.remove(backup_name)
			var rotate_err := dir.rename(file_name, backup_name)
			if rotate_err != OK:
				push_warning("存档：无法轮换旧存档（%s）" % error_string(rotate_err))
				dir.remove(temp_name)
				return false
	var rename_err := dir.rename(temp_name, file_name)
	if rename_err != OK:
		push_warning("存档：无法写入正式存档（%s）" % error_string(rename_err))
		if not keep_backup and dir.file_exists(backup_name):
			dir.rename(backup_name, file_name)
		return false
	return true


## 只删除磁盘文件，不改变当前内存状态
func delete(slot: int) -> bool:
	if not is_valid_slot(slot):
		return false
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return true
	var file_name := slot_file(slot)
	var ok := true
	for target in [file_name, file_name + ".bak", file_name + ".tmp"]:
		if dir.file_exists(target) and dir.remove(target) != OK:
			ok = false
	return ok


func has_save(slot: int) -> bool:
	if not is_valid_slot(slot):
		return false
	return FileAccess.file_exists(slot_path(slot)) \
			or FileAccess.file_exists(backup_path(slot))


func path(slot: int) -> String:
	return slot_path(slot)


func set_read_only(on: bool) -> void:
	_read_only = on


func is_read_only() -> bool:
	return _read_only


func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("存档：无法读取 %s（%s）" % [file_path, error_string(FileAccess.get_open_error())])
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("存档：%s JSON 解析失败" % file_path)
		return {}
	var data := parsed as Dictionary
	if SaveDocument.version_of(data) <= 0:
		push_warning("存档：%s 缺少版本号" % file_path)
		return {}
	return data


func _ensure_save_dir() -> bool:
	var absolute := ProjectSettings.globalize_path(SAVE_DIR)
	if DirAccess.dir_exists_absolute(absolute):
		return true
	var err := DirAccess.make_dir_recursive_absolute(absolute)
	if err != OK:
		push_warning("存档：无法创建目录 %s（%s）" % [SAVE_DIR, error_string(err)])
		return false
	return true
