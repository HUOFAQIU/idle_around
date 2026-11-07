extends SceneTree
## 校验内置 core mod 的 manifest 与内容文件是否一致。
##
## 用法：
##   Godot_v4.7.2... --headless --path <项目> --script res://modkit/validate_core_manifest.gd
##
## 退出码：0 = 通过；1 = 有错误。检查项：manifest 格式、core 身份、
## 魂灵/怪物/Cue 条目与目录文件的一一对应、重复 ID/路径。

const CORE_CONTENT_VALIDATOR := preload("res://Scripts/mod/core_content_validator.gd")


func _init() -> void:
	var errors: Array[String] = CORE_CONTENT_VALIDATOR.validate()
	if errors.is_empty():
		print("core manifest 校验通过。")
		quit(0)
		return
	for message in errors:
		printerr("core manifest: " + message)
	quit(1)
