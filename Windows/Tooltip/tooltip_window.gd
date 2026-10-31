class_name TooltipWindow
extends Window

static var instance : TooltipWindow

## 提示框跟鼠标隔开多少像素
const GAP : float = 10.0

## tooltip 层级：数值越大越优先，低层级不能覆盖仍然有效的高层级
enum Layer { COORD, ITEM }

## 本帧结算出来的显隐目标。
## 信号的收发发生在输入阶段、_process 在其后，所以一帧内的 hide + show
## 会被合并成「保持显示」—— Window 的 visible 是真的去 OS 那里撤窗口、建窗口，
## 同帧一撤一建，肉眼就是闪一下。
var _want_visible : bool = false
## 本帧收到过隐藏请求
var _hide_armed : bool = false
## 当前占用 tooltip 的对象；真正隐藏时清空
var _owner : Object
## 当前层级，默认是战斗坐标
var _layer : int = Layer.COORD


func _ready() -> void:
	instance = self
	visible = false


func _process(_delta: float) -> void:
	if _hide_armed:
		_hide_armed = false
		_want_visible = false
		_owner = null
	# 先摆位再显示，免得在上一帧的位置上闪一下
	if _want_visible:
		_place_tip()
	if visible != _want_visible:
		visible = _want_visible


## 显示提示框；低层级不能覆盖仍然有效的高层级 owner。
## 本帧内收到的隐藏请求作废。
func show_tip(owner: Object, layer: int, title_name: String) -> void:
	if is_instance_valid(_owner) and _owner != owner and layer < _layer and not _hide_armed:
		return
	_owner = owner
	_layer = layer
	# 标题栏是原生窗口的一部分，同一个字符串反复写也会让系统重绘标题栏。
	# 战斗窗口每个物理帧都会调进来，所以只在文字真的变了才写。
	if title != title_name:
		title = title_name
	_hide_armed = false
	_want_visible = true


## 收起来；只有当前 owner 能收，避免战斗窗口把物品提示关掉。
## 延迟到本帧末结算，期间又被 show 的话就不闪。
func hide_tip(owner: Object) -> void:
	if is_instance_valid(_owner) and _owner != owner:
		return
	_hide_armed = true


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
	# 原生窗口每写一次 position 都是一次 OS 调用。鼠标停着不动时，
	# 每帧重复写同一个坐标会让窗口管理器做无用功，看起来就是“卡”。
	var target := Vector2i(pos)
	if position != target:
		position = target
