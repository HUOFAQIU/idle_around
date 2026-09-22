extends Node


func _ready() -> void:
	_place_window_bottom_left()


# 把主窗口贴到当前屏幕的最左下角，位置依据屏幕可用区域动态计算。
func _place_window_bottom_left() -> void:
	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	var win: Vector2i = DisplayServer.window_get_size()
	# 左下角：x 贴左边(usable.position.x)，y 贴可用区域底边减去窗口高度
	var pos := Vector2i(usable.position.x + GameGlobal.WINDOWPOSOFFSET, usable.position.y + usable.size.y - win.y - GameGlobal.WINDOWPOSOFFSET)
	DisplayServer.window_set_position(pos)
