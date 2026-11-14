## 单槽存档的磁盘读写：临时文件 + 备份轮换 + 只读态。
##
## 只认 JSON 字典与版本号是否存在，不解释业务 section；
## 业务数据由 SaveDocument 与 participant 负责。
class_name SaveStorage extends RefCounted

const SAVE_DIR: String = "user://saves"
const SAVE_FILE: String = "slot_0.json"
const SAVE_PATH: String = SAVE_DIR + "/" + SAVE_FILE
const BACKUP_FILE: String = SAVE_FILE + ".bak"
const TEMP_FILE: String = SAVE_FILE + ".tmp"
const TEMP_PATH: String = SAVE_DIR + "/" + TEMP_FILE
const BACKUP_PATH: String = SAVE_DIR + "/" + BACKUP_FILE

var _read_only: bool = false


func read_primary() -> Dictionary:
	return _read(SAVE_PATH)


func read_backup() -> Dictionary:
	return _read(BACKUP_PATH)


## 原子写：先写临时文件，再轮换主文件/备份
func write(data: Dictionary, keep_backup: bool = false) -> bool:
	if not _ensure_save_dir():
		return false
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("存档：无法写入临时文件 %s（%s）" % [TEMP_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()

	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		push_warning("存档：无法打开目录 %s" % SAVE_DIR)
		return false
	if dir.file_exists(SAVE_FILE):
		if keep_backup:
			# 主文件已经损坏；只替换主文件，保留刚恢复用的好备份
			var remove_err := dir.remove(SAVE_FILE)
			if remove_err != OK:
				push_warning("存档：无法移除损坏的主存档（%s）" % error_string(remove_err))
				dir.remove(TEMP_FILE)
				return false
		else:
			if dir.file_exists(BACKUP_FILE):
				dir.remove(BACKUP_FILE)
			var rotate_err := dir.rename(SAVE_FILE, BACKUP_FILE)
			if rotate_err != OK:
				push_warning("存档：无法轮换旧存档（%s）" % error_string(rotate_err))
				dir.remove(TEMP_FILE)
				return false
	var rename_err := dir.rename(TEMP_FILE, SAVE_FILE)
	if rename_err != OK:
		push_warning("存档：无法写入正式存档（%s）" % error_string(rename_err))
		if not keep_backup and dir.file_exists(BACKUP_FILE):
			dir.rename(BACKUP_FILE, SAVE_FILE)
		return false
	return true


## 只删除磁盘文件，不改变当前内存状态
func delete() -> bool:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return true
	var ok := true
	for file_name in [SAVE_FILE, BACKUP_FILE, TEMP_FILE]:
		if dir.file_exists(file_name) and dir.remove(file_name) != OK:
			ok = false
	return ok


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


func path() -> String:
	return SAVE_PATH


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
