extends SceneTree

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
