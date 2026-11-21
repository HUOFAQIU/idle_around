extends Node
class_name MovingItemService

signal drag_started(item: ItemData)
signal drag_ended

var moving_item: ItemData
var moving_item_offset: Vector2i = Vector2i.ZERO
var _presenter := DragPresenter.new()

var _origin: DragOrigin


func is_dragging() -> bool:
	return moving_item != null


func pick_from_grid(container_name: String, grid_id: Vector2i, offset: Vector2i, base_size: int) -> bool:
	if moving_item:
		push_error("Already had moving item.")
		return false
	var item_data := GBIS.inventory_service.find_item_data_by_grid(container_name, grid_id)
	if item_data == null:
		return false
	GBIS.inventory_service.remove_item_by_data(container_name, item_data)
	_begin(item_data, offset, base_size, DragOrigin.from_grid(container_name, grid_id - offset))
	return true


func pick_from_slot(slot_name: String, base_size: int) -> bool:
	if moving_item:
		push_error("Already had moving item.")
		return false
	var item_data := GBIS.equipment_slot_service.take_from_slot(slot_name)
	if item_data == null:
		return false
	_begin(item_data, Vector2i.ZERO, base_size, DragOrigin.from_slot(slot_name))
	return true


func begin_detached(item_data: ItemData, offset: Vector2i, base_size: int) -> void:
	if moving_item:
		push_error("Already had moving item.")
		return
	_begin(item_data, offset, base_size, DragOrigin.none())


func drop_on_grid(container_name: String, grid_id: Vector2i) -> bool:
	if moving_item == null:
		return false
	var state := GBIS.inventory_service.drop_state_at(container_name, moving_item, grid_id, moving_item_offset)
	var placed := false
	match state:
		ContainerData.DropState.PLACE:
			placed = GBIS.inventory_service.place_moving_item(container_name, grid_id)
		ContainerData.DropState.STACK:
			placed = GBIS.inventory_service.stack_moving_item(container_name, grid_id - moving_item_offset)
		_:
			return false
	if placed:
		finish()
	return placed


func drop_on_slot(slot_name: String) -> bool:
	if moving_item == null:
		return false
	if not GBIS.equipment_slot_service.equip_moving_item(slot_name):
		return false
	finish()
	return true


func sell_dragged() -> bool:
	if moving_item == null:
		return false
	if not GBIS.shop_service.sell_item(moving_item):
		return false
	finish()
	return true


func drop_to_world() -> bool:
	if moving_item == null or not moving_item.can_drop():
		return false
	moving_item.drop()
	finish()
	return true


func cancel() -> bool:
	if moving_item == null or _origin == null:
		return false
	var restored := false
	match _origin.kind:
		DragOrigin.Kind.GRID:
			restored = GBIS.inventory_service.restore_to_grid(_origin.container_name, _origin.grid, moving_item)
		DragOrigin.Kind.SLOT:
			restored = GBIS.equipment_slot_service.restore_to_slot(_origin.slot_name, moving_item)
	if not restored:
		return false
	finish()
	return true


func finish() -> void:
	_presenter.end()
	moving_item = null
	moving_item_offset = Vector2i.ZERO
	_origin = null
	drag_ended.emit()


func apply_stack_style(base_size: int, font: Font, font_size: int, margin: int, color: Color) -> void:
	_presenter.apply_stack_style(base_size, font, font_size, margin, color)


func set_drag_base_size(base_size: int) -> void:
	_presenter.set_base_size(base_size)


func register_drop_area(area: DropAreaView) -> void:
	_presenter.register_drop_area(area)


func _begin(item_data: ItemData, offset: Vector2i, base_size: int, origin: DragOrigin) -> void:
	moving_item = item_data
	moving_item_offset = offset
	_origin = origin
	_presenter.begin(item_data, offset, base_size)
	drag_started.emit(item_data)
