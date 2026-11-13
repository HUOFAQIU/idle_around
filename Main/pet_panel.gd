class_name PetPanel
extends Control
## 主界面浮层：空白处左键拖动，位置保存到 user://Settings.cfg。
##
## Background 是 MOUSE_FILTER_IGNORE，按钮自己消费点击，所以只有
## PetPanel 的空白区域会开始拖动。

var _drag : ControlDrag
## 上次保存/恢复的位置；视口尺寸变化时按它重新摆放
var _saved_position : Vector2 = Vector2.ZERO
## 有可用的已保存位置；没有则用左下角默认位
var _has_saved_position : bool = false


func _ready() -> void:
	_drag = ControlDrag.new()
	_drag.drag_ended.connect(_on_drag_ended)
	_drag.bind(self, self, get_parent() as Control)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	# 等一帧让全屏/DPI 后的视口尺寸稳定，再读位置
	_restore_position_after_frame()


## 供 TestAPI / 调试使用：移动到指定位置并持久化
func move_to(target_position : Vector2) -> void:
	position = _clamp_position(target_position)
	_saved_position = position
	_has_saved_position = true
	PetPanelSettings.save_position(position)


func _restore_position_after_frame() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_restore_position()


func _restore_position() -> void:
	var saved := PetPanelSettings.load_position()
	_has_saved_position = PetPanelSettings.has_position() and saved != PetPanelSettings.NO_SAVED_POSITION
	_saved_position = saved if _has_saved_position else _default_position()
	position = _clamp_position(_saved_position)


func _default_position() -> Vector2:
	var margin := float(GameGlobal.WINDOWPOSOFFSET)
	return Vector2(margin, get_viewport_rect().size.y - size.y - margin)


func _clamp_position(target_position : Vector2) -> Vector2:
	return UiBounds.clamp_position(target_position, size, get_viewport_rect().size)


func _on_drag_ended() -> void:
	if position == _saved_position:
		return
	_saved_position = position
	_has_saved_position = true
	PetPanelSettings.save_position(position)


func _on_viewport_size_changed() -> void:
	# 只重新摆放，不写盘：启动/DPI 过渡的临时尺寸不能覆盖用户保存的位置
	var target := _saved_position if _has_saved_position else _default_position()
	position = _clamp_position(target)
