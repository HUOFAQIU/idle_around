class_name ClawSlashPainter
extends Node2D
## 爪痕绘制：三道弧形、入口粗出口细的划痕，按 progress 从左往右显现。
##
## 只负责画，不管生命周期；方向由 play(direction) 通过 scale.x = -1 镜像。
## 绘制永远按“从左往右”取样，镜像后看起来就是从右往左。

## 爪痕总跨度（像素）
const LENGTH : float = 48.0
## 三道爪痕的纵向间距
const SPACING : float = 9.0
## 入口处最粗的半宽（像素）
const MAX_HALF_WIDTH : float = 2.4
## 出口处最细的半宽（像素）
const MIN_HALF_WIDTH : float = 0.35
## 每道爪痕的取样段数；越大曲线越顺
const SEGMENTS : int = 14
## 斜向：出口相对入口下沉的像素
const SLOPE : float = 9.0
## 弧顶高度（像素）
const ARC : float = 2.5
## 横扫时长（秒）
const SWEEP_TIME : float = 0.11
## 划完后保持满亮度的时长（秒）
const HOLD_TIME : float = 0.05
## 淡出时长（秒）
const FADE_TIME : float = 0.16
const SLASH_COUNT : int = 3

## 0~1 的显现进度；由 play() 的补间推进
var progress : float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
## 0~1 的整体透明度；由 play() 的补间推进
var strength : float = 1.0:
	set(value):
		strength = clampf(value, 0.0, 1.0)
		queue_redraw()

var _tween : Tween


## 从一侧扫到另一侧；direction < 0 时整道特效镜像成从右往左。
## 每次重新随机一点角度和纵向偏移，避免连击的两刀完全重合。
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

	# 先铺一层暗红辉光，再压暖白爪痕，最后点出正在划的亮头
	for index in SLASH_COUNT:
		_draw_stroke(index, progress, glow, 2.0)
	for index in SLASH_COUNT:
		_draw_stroke(index, progress, core, 1.0)
		if progress < 1.0:
			draw_circle(_point_at(index, progress), 1.8, head)


## 第 index 道爪痕在 t（0~1）处的中心点
func _point_at(index: int, t: float) -> Vector2:
	var length_scale := _length_scale(index)
	var x := (t - 0.5) * LENGTH * length_scale
	var y := (float(index) - 1.0) * SPACING + (t - 0.5) * SLOPE + sin(t * PI) * ARC
	return Vector2(x, y)


## 中心线在 t 处的单位法线；数值切线足够，不用解析求导
func _normal_at(index: int, t: float) -> Vector2:
	const EPSILON : float = 0.01
	var before := _point_at(index, maxf(t - EPSILON, 0.0))
	var after := _point_at(index, minf(t + EPSILON, 1.0))
	var tangent := (after - before).normalized()
	return Vector2(-tangent.y, tangent.x)


## 半宽从入口到出口渐细；入口即爪尖落点，保持最大宽度
func _half_width(index: int, t: float) -> float:
	var taper := pow(1.0 - t, 0.65)
	return (MIN_HALF_WIDTH + (MAX_HALF_WIDTH - MIN_HALF_WIDTH) * taper) * _length_scale(index)


## 两侧的爪痕略短，中间的略长
func _length_scale(index: int) -> float:
	return 1.0 - absf(float(index) - 1.0) * 0.08


## 把 t=0..reveal 的一段画成一条渐细的带状多边形
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
