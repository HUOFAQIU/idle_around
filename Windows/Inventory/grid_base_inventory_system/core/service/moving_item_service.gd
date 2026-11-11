extends Node
## 拖拽状态机：拿起、放下、出售、丢弃、取消的唯一入口。
##
## 表现交给 DragPresenter；能否放下由 ContainerData.drop_state_at() /
## EquipmentSlotData.can_accept() 判定；各 service 只做存储操作，不直接清拖拽。
class_name MovingItemService

## 开始拖拽
signal drag_started(item: ItemData)
## 拖拽结束（放下、出售、丢弃或取消）
signal drag_ended

## 正在移动的物品
var moving_item: ItemData
## 正在移动的物品的偏移（例：一个2*2的物品，点击左上角移动时，偏移是[0,0]，点击右下角移动时，偏移是[1,1]）
var moving_item_offset: Vector2i = Vector2i.ZERO
## 拖拽表现
var _presenter := DragPresenter.new()

## 拖拽来源；取消时按来源恢复
var _origin: DragOrigin


## 是否有物品正在拖拽
func is_dragging() -> bool:
	return moving_item != null


## 从容器格子拿起物品
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


## 从装备槽拿起物品
func pick_from_slot(slot_name: String, base_size: int) -> bool:
	if moving_item:
		push_error("Already had moving item.")
		return false
	var item_data := GBIS.equipment_slot_service.take_from_slot(slot_name)
	if item_data == null:
		return false
	_begin(item_data, Vector2i.ZERO, base_size, DragOrigin.from_slot(slot_name))
	return true


## 分割等没有原格的拖拽
func begin_detached(item_data: ItemData, offset: Vector2i, base_size: int) -> void:
	if moving_item:
		push_error("Already had moving item.")
		return
	_begin(item_data, offset, base_size, DragOrigin.none())


## 放到容器格子；空格放置和堆叠合并由 drop_state_at 决定
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


## 放到装备槽
func drop_on_slot(slot_name: String) -> bool:
	if moving_item == null:
		return false
	if not GBIS.equipment_slot_service.equip_moving_item(slot_name):
		return false
	finish()
	return true


## 在商店出售手中物品
func sell_dragged() -> bool:
	if moving_item == null:
		return false
	if not GBIS.shop_service.sell_item(moving_item):
		return false
	finish()
	return true


## 丢到世界
func drop_to_world() -> bool:
	if moving_item == null or not moving_item.can_drop():
		return false
	moving_item.drop()
	finish()
	return true


## 右键取消：按来源放回；无来源的拖拽保持原样
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


## 结束拖拽并清理表现；成功放下、出售、丢弃、取消都走这里
func finish() -> void:
	_presenter.end()
	moving_item = null
	moving_item_offset = Vector2i.ZERO
	_origin = null
	drag_ended.emit()


## 同步背包/商店的格子与堆叠样式
func apply_stack_style(base_size: int, font: Font, font_size: int, margin: int, color: Color) -> void:
	_presenter.apply_stack_style(base_size, font, font_size, margin, color)


## 同步装备槽的格子大小
func set_drag_base_size(base_size: int) -> void:
	_presenter.set_base_size(base_size)


## DropAreaView 入树时注册
func register_drop_area(area: DropAreaView) -> void:
	_presenter.register_drop_area(area)


func _begin(item_data: ItemData, offset: Vector2i, base_size: int, origin: DragOrigin) -> void:
	moving_item = item_data
	moving_item_offset = offset
	_origin = origin
	_presenter.begin(item_data, offset, base_size)
	drag_started.emit(item_data)
