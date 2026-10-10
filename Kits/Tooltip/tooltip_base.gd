class_name TooltipBase
extends Control

## 提示框跟鼠标隔开多少像素
const GAP : float = 10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

## 收起来
func hide_tip() -> void:
	visible = false

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
