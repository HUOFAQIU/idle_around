class_name TooltipWindow
extends Window

static var instance : TooltipWindow

## 提示框跟鼠标隔开多少像素
const GAP : float = 10.0

## 本帧结算出来的显隐目标。
## 信号的收发发生在输入阶段、_process 在其后，所以一帧内的 hide + show
## 会被合并成「保持显示」—— Window 的 visible 是真的去 OS 那里撤窗口、建窗口，
## 同帧一撤一建，肉眼就是闪一下。
var _want_visible : bool = false
## 本帧收到过隐藏请求
var _hide_armed : bool = false


func _ready() -> void:
	instance = self
	visible = false


func _process(_delta: float) -> void:
	if _hide_armed:
		_hide_armed = false
		_want_visible = false
	# 先摆位再显示，免得在上一帧的位置上闪一下
	if _want_visible:
		_place_tip()
	if visible != _want_visible:
		visible = _want_visible


## 显示提示框；本帧内收到的隐藏请求作废
func show_tip() -> void:
	_hide_armed = false
	_want_visible = true


## 收起来；延迟到本帧末结算，期间又被 show 的话就不闪
func hide_tip() -> void:
	_hide_armed = true


func set_window_title(title_name : String) -> void:
	title = title_name


## 自己决定往哪边弹：锚点是鼠标，边界是屏幕
func _place_tip() -> void:
	_place_near(DisplayServer.mouse_get_position(), DisplayServer.screen_get_size())


## 摆位：默认在鼠标右下方，右边放不下就翻到左边，翻过头再夹回窗口里。
func _place_near(anchor: Vector2, bounds: Vector2) -> void:
	var tip := size
	
	var pos := anchor + Vector2(GAP, GAP)
	if pos.x + tip.x > bounds.x:
		pos.x = anchor.x - GAP - tip.x
	if pos.y + tip.y > bounds.y:
		pos.y = anchor.y - GAP - tip.y
	
	pos.x = clampf(pos.x, 0.0, maxf(0.0, bounds.x - tip.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, bounds.y - tip.y))
	position = pos
