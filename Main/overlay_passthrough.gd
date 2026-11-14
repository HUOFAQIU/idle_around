class_name OverlayPassthrough
extends Node
## 透明覆盖层的鼠标穿透。
##
## Windows 上 Godot 的 mouse_passthrough 只传给同一应用的窗口，跨应用穿透
## 必须用 mouse_passthrough_polygon（窗口区域）。这里把 PetPanel、可见面板
## 和 Tooltip/Item 浮层合成一个多边形；区域外点击落到桌面，区域内仍可交互。
## 每块矩形向外扩 REGION_MARGIN 像素，边缘不贴死，相邻区域也更容易连成一片。

## 参与命中的 UI 矩形向外扩的像素
const REGION_MARGIN : int = 8

static var instance : OverlayPassthrough

## 总开关；关掉后窗口始终可交互
var enabled : bool = true:
	set(value):
		enabled = value
		if enabled:
			_refresh_region()
		else:
			_clear_region()

## 鼠标在 UI 上按下后把窗口临时扩成整个客户区，松开后恢复
var _locked : bool = false
var _last_rects : Array[Rect2] = []
var _pet_panel : Control
var _panel_manager : PanelManager
var _tooltip : Control
var _item_window : Control


func _ready() -> void:
	instance = self
	var parent := get_parent()
	if parent != null:
		_pet_panel = parent.get_node_or_null("PetPanel") as Control
		_panel_manager = parent.get_node_or_null("PanelManager") as PanelManager
		_tooltip = parent.get_node_or_null("TooltipLayer/TooltipWindow") as Control
		_item_window = parent.get_node_or_null("DragLayer/ItemWindow") as Control
	var window := get_window()
	if window != null:
		# 这个开关在 Windows 上只对同应用窗口生效；区域方案要求它保持 false
		window.mouse_passthrough = false
	_refresh_region()


func _exit_tree() -> void:
	if instance == self:
		instance = null
	_clear_region()


func _process(_delta : float) -> void:
	if not enabled:
		return
	if _locked:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
				and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_locked = false
			_refresh_region()
		return
	var rects := _collect_rects()
	if rects != _last_rects:
		_last_rects = rects
		_apply_region(rects)


func _input(event : InputEvent) -> void:
	if not enabled or _locked or not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if not mouse_button.pressed:
		return
	if mouse_button.button_index != MOUSE_BUTTON_LEFT and mouse_button.button_index != MOUSE_BUTTON_RIGHT:
		return
	# 在 UI 上按下：临时扩到整个客户区，拖动/松开过程中保持交互
	_locked = true
	_apply_region([Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)])


func is_locked() -> bool:
	return _locked


## 当前参与命中的 UI 矩形（PetPanel + 可见面板 + Tooltip/Item，已按 REGION_MARGIN 外扩）
func get_hit_rects() -> Array[Rect2]:
	return _last_rects.duplicate()


## 当前设置的窗口区域多边形；TestAPI/调试用
func get_polygon_points() -> PackedVector2Array:
	var window := get_window()
	if window == null:
		return PackedVector2Array()
	return window.mouse_passthrough_polygon


func _collect_rects() -> Array[Rect2]:
	var rects : Array[Rect2] = []
	var area := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	if _pet_panel != null and _pet_panel.is_visible_in_tree():
		rects.append(_expand(_pet_panel.get_global_rect(), area))
	if _panel_manager != null:
		for rect in _panel_manager.get_visible_panel_rects():
			rects.append(_expand(rect, area))
	if _tooltip != null and _tooltip.is_visible_in_tree():
		rects.append(_expand(_tooltip.get_global_rect(), area))
	if _item_window != null and _item_window.is_visible_in_tree():
		rects.append(_expand(_item_window.get_global_rect(), area))
	return rects


## 命中/绘制区域在 UI 矩形外留一圈缓冲，并裁到客户区内
func _expand(rect : Rect2, area : Rect2) -> Rect2:
	return rect.grow(REGION_MARGIN).intersection(area)


func _refresh_region() -> void:
	var rects := _collect_rects()
	_last_rects = rects
	_apply_region(rects)


func _apply_region(rects : Array[Rect2]) -> void:
	var window := get_window()
	if window == null:
		return
	window.mouse_passthrough = false
	var polygon := UiRegion.build(rects)
	if polygon.is_empty():
		# 没有任何 UI 时只留 1×1 区域，让其余客户区全部穿透
		polygon = UiRegion.full_window(Vector2.ONE)
	window.mouse_passthrough_polygon = polygon


func _clear_region() -> void:
	var window := get_window()
	if window == null:
		return
	window.mouse_passthrough = false
	# 空数组 = 取消区域穿透，所有鼠标事件由窗口拦截
	window.mouse_passthrough_polygon = PackedVector2Array()
