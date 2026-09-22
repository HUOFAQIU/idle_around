class_name CharacterWindow
extends BaseWindow


func _ready() -> void:
	super()

	title = "人物窗口"
	# 打开位置写在场景里（character_window.tscn 的 open_position），
	# 在这儿设 position 没用：control.gd 打开时会 popup，位置会被覆盖
