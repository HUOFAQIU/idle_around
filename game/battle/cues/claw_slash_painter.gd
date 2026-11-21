class_name ClawSlashPainter
extends Node2D

const LENGTH : float = 48.0
const SPACING : float = 9.0
const MAX_HALF_WIDTH : float = 2.4
const MIN_HALF_WIDTH : float = 0.35
const SEGMENTS : int = 14
const SLOPE : float = 9.0
const ARC : float = 2.5
const SWEEP_TIME : float = 0.11
const HOLD_TIME : float = 0.05
const FADE_TIME : float = 0.16
const SLASH_COUNT : int = 3

var progress : float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var strength : float = 1.0:
	set(value):
		strength = clampf(value, 0.0, 1.0)
		queue_redraw()

var _tween : Tween


func play(direction: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	rotation = randf_range(-0.12, 0.12)
	position = Vector2(0.0, randf_range(-2.0, 2.0))
	scale = Vector2(-1.0 if direction < 0.0 else 1.0, 1.0)
	progress = 0.0
	strength = 1.0

	_tween = create_tween()
	_tween.tween_property(self, "progress", 1.0, SWEEP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(self, "strength", 0.0, FADE_TIME)


func _draw() -> void:
	if strength <= 0.001 or progress <= 0.0:
		return
	var glow := GameColors.to_color(GameColors.DAMAGE)
	glow.a = 0.3 * strength
	var core := GameColors.to_color(GameColors.CLAW_SLASH)
	core.a = 0.9 * strength
	var head := GameColors.to_color(GameColors.TEXT_PRIMARY)
	head.a = strength

	for index in SLASH_COUNT:
		_draw_stroke(index, progress, glow, 2.0)
	for index in SLASH_COUNT:
		_draw_stroke(index, progress, core, 1.0)
		if progress < 1.0:
			draw_circle(_point_at(index, progress), 1.8, head)


func _point_at(index: int, t: float) -> Vector2:
	var length_scale := _length_scale(index)
	var x := (t - 0.5) * LENGTH * length_scale
	var y := (float(index) - 1.0) * SPACING + (t - 0.5) * SLOPE + sin(t * PI) * ARC
	return Vector2(x, y)


func _normal_at(index: int, t: float) -> Vector2:
	const EPSILON : float = 0.01
	var before := _point_at(index, maxf(t - EPSILON, 0.0))
	var after := _point_at(index, minf(t + EPSILON, 1.0))
	var tangent := (after - before).normalized()
	return Vector2(-tangent.y, tangent.x)


func _half_width(index: int, t: float) -> float:
	var taper := pow(1.0 - t, 0.65)
	return (MIN_HALF_WIDTH + (MAX_HALF_WIDTH - MIN_HALF_WIDTH) * taper) * _length_scale(index)


func _length_scale(index: int) -> float:
	return 1.0 - absf(float(index) - 1.0) * 0.08


func _draw_stroke(index: int, reveal: float, color: Color, width_scale: float) -> void:
	var steps := maxi(2, ceili(reveal * SEGMENTS))
	var points := PackedVector2Array()
	for step in steps + 1:
		var t := reveal * float(step) / float(steps)
		points.append(
			_point_at(index, t) + _normal_at(index, t) * _half_width(index, t) * width_scale
		)
	for step in range(steps, -1, -1):
		var t := reveal * float(step) / float(steps)
		points.append(
			_point_at(index, t) - _normal_at(index, t) * _half_width(index, t) * width_scale
		)
	draw_colored_polygon(points, color)
