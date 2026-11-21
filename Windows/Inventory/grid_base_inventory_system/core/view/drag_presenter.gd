extends RefCounted
class_name DragPresenter

var _view: ItemView
var _drop_area: DropAreaView


func begin(item_data: ItemData, grab_offset: Vector2i, base_size: int) -> void:
	_view = null
	if ItemWindow.instance:
		_view = ItemView.new(item_data, base_size)
		ItemWindow.instance.hold(_view, grab_offset, base_size)
	if _drop_area:
		_drop_area.show()


func end() -> void:
	if _view != null and not _view.is_inside_tree():
		_view.queue_free()
	if ItemWindow.instance:
		ItemWindow.instance.clear()
	_view = null
	if _drop_area:
		_drop_area.hide()


func apply_stack_style(base_size: int, font: Font, font_size: int, margin: int, color: Color) -> void:
	if _view == null:
		return
	_view.base_size = base_size
	_view.stack_num_font = font
	_view.stack_num_font_size = font_size
	_view.stack_num_margin = margin
	_view.stack_num_color = color


func set_base_size(base_size: int) -> void:
	if _view:
		_view.base_size = base_size


func register_drop_area(area: DropAreaView) -> void:
	_drop_area = area
