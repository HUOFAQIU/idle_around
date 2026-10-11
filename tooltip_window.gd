class_name TooltipWindow
extends Window

## 提示框跟鼠标隔开多少像素
const GAP : float = 10.0

func _ready() -> void:
	#mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _process(_delta: float) -> void:
	if visible:
		place_tip()

## 摆位：默认在鼠标右下方，右边放不下就翻到左边，翻过头再夹回窗口里。
func place_near(anchor: Vector2, bounds: Vector2) -> void:
	var tip := size
	
	var pos := anchor + Vector2(GAP, GAP)
	if pos.x + tip.x > bounds.x:
		pos.x = anchor.x - GAP - tip.x
	if pos.y + tip.y > bounds.y:
		pos.y = anchor.y - GAP - tip.y
	
	pos.x = clampf(pos.x, 0.0, maxf(0.0, bounds.x - tip.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, bounds.y - tip.y))
	position = pos

## 自己决定往哪边弹：锚点是鼠标，边界是自己所在窗口的矩形
func place_tip() -> void:
	place_near(DisplayServer.mouse_get_position(), DisplayServer.screen_get_size())

## 收起来
func hide_tip() -> void:
	visible = false
