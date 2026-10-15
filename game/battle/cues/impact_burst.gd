## 命中火花：一圈往外扩、同时淡掉的环。
##
## 注意 cue 是走对象池反复重用的 —— 每次 play() 之前必须把状态复位，
## 不然第二下会接着上一次的半径继续炸。

class_name ImpactBurst extends Node2D

const COLOR := Color(1.0, 0.92, 0.6)
const START_RADIUS : float = 3.0
const END_RADIUS : float = 22.0
const DURATION : float = 0.25
const LINE_WIDTH : float = 2.0

var _radius : float = START_RADIUS
var _alpha : float = 0.0


func play() -> void:
	_radius = START_RADIUS
	_alpha = 1.0
	queue_redraw()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_radius, START_RADIUS, END_RADIUS, DURATION)
	tween.tween_method(_set_alpha, 1.0, 0.0, DURATION)


func _set_radius(value: float) -> void:
	_radius = value
	queue_redraw()


func _set_alpha(value: float) -> void:
	_alpha = value
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 24, Color(COLOR.r, COLOR.g, COLOR.b, _alpha), LINE_WIDTH)
