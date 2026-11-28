extends Resource
class_name ContainerData

enum DropState {
	BLOCKED,
	PLACE,
	STACK,
}

## 库存列数
@export_storage var columns: int = 2
## 库存行数
@export_storage var rows: int = 2
## 库存名称
@export_storage var container_name: String
## 允许存放的物品大类列表
@export_storage var avilable_types: Array[String]
## 魂器类型限制（空 = 不限制；COMBAT / TOOL）
@export_storage var vessel_kind: String = ""
## 最多容纳物品件数；0 = 不限制（角色魂器网格不设）
@export_storage var max_items: int = 0

## 当前存放的物品数据列表
@export_storage var items: Array[ItemData] = []
## 物品到占据网格的映射(Array[grid_id: Vector2i])
@export_storage var item_grids_map: Dictionary[ItemData, Array]
## 格子到物品的映射
@export_storage var grid_item_map: Dictionary[Vector2i, ItemData] = {}
var _owner_ref: WeakRef = null

@warning_ignore("shadowed_variable")
func _init(container_name: String = GBIS.DEFAULT_INVENTORY_NAME, columns: int = 0, rows: int = 0, avilable_types: Array[String] = []) -> void:
	self.container_name = container_name
	self.avilable_types = avilable_types
	self.columns = columns
	self.rows = rows
	for row in rows:
		for col in columns:
			var pos = Vector2i(col, row)
			grid_item_map[pos] = null

func clear() -> void:
	items = []
	item_grids_map = {}
	for row in rows:
		for col in columns:
			var pos = Vector2i(col, row)
			grid_item_map[pos] = null

func deep_duplicate() -> ContainerData:
	var ret = ContainerData.new(container_name, columns, rows, avilable_types)
	ret.vessel_kind = vessel_kind
	ret.max_items = max_items
	for item_data in item_grids_map.keys():
		ret.item_grids_map[item_data.make_instance()] = item_grids_map[item_data].duplicate(true)
	ret.items.append_array(ret.item_grids_map.keys())
	for item in ret.items:
		var grids = ret.item_grids_map[item]
		for grid in grids:
			ret.grid_item_map[grid] = item
	return ret

func add_item(item_data: ItemData) -> Array[Vector2i]:
	if not is_item_avilable(item_data):
		return []
	var grids = _find_first_availble_grids(item_data)
	_add_item_to_grids(item_data, grids)
	return grids

func remove_item(item: ItemData) -> bool:
	if items.has(item):
		var grids = item_grids_map[item]
		for grid in grids:
			grid_item_map[grid] = null
		items.erase(item)
		item_grids_map.erase(item)
		return true
	return false

func is_item_avilable(item_data: ItemData) -> bool:
	if not (avilable_types.has("ANY") or avilable_types.has(item_data.category)):
		return false
	if max_items > 0 and items.size() >= max_items and not items.has(item_data):
		return false
	if vessel_kind != "" and item_data.container_kind_tag() != vessel_kind:
		return false
	return true


func drop_state_at(item_data: ItemData, hovered_grid: Vector2i, grab_offset: Vector2i) -> DropState:
	if not is_item_avilable(item_data):
		return DropState.BLOCKED
	var start := hovered_grid - grab_offset
	var shape := item_data.get_shape()
	var occupant: ItemData = null
	var covered := 0
	var occupied := 0
	for row in shape.y:
		for col in shape.x:
			var grid := Vector2i(start.x + col, start.y + row)
			if not grid_item_map.has(grid):
				return DropState.BLOCKED
			covered += 1
			var cell_item: ItemData = grid_item_map[grid]
			if cell_item == null:
				continue
			occupied += 1
			if occupant == null:
				occupant = cell_item
			elif occupant != cell_item:
				return DropState.BLOCKED
	if occupant == null:
		return DropState.PLACE
	if occupied != covered:
		return DropState.BLOCKED
	if item_data is StackableData and occupant is StackableData and item_data.item_name == occupant.item_name:
		var occupant_grids: Array = item_grids_map.get(occupant, [])
		if not occupant.is_full() and occupant_grids.size() == covered:
			return DropState.STACK
	return DropState.BLOCKED

func find_grids_by_item_data(item_data: ItemData) -> Array[Vector2i]:
	return item_grids_map.get(item_data, [] as Array[Vector2i])


static func anchor_of(grids: Array[Vector2i]) -> Vector2i:
	var anchor: Vector2i = grids[0]
	for grid in grids:
		anchor.x = mini(anchor.x, grid.x)
		anchor.y = mini(anchor.y, grid.y)
	return anchor

func has_item(item: ItemData) -> bool:
	return items.has(item)

func find_item_data_by_grid(grid_id: Vector2i) -> ItemData:
	return grid_item_map.get(grid_id)

func try_add_to_grid(item_data: ItemData, grid_id: Vector2i) -> Array[Vector2i]:
	if drop_state_at(item_data, grid_id, Vector2i.ZERO) != DropState.PLACE:
		return []
	var grids = _try_get_empty_grids_by_shape(grid_id, item_data.get_shape())
	_add_item_to_grids(item_data, grids)
	return grids

func find_item_data_by_item_name(item_name: String) -> Array[ItemData]:
	var ret: Array[ItemData] = []
	for item in items:
		if item.item_name == item_name:
			ret.append(item)
	return ret

func _add_item_to_grids(item_data: ItemData, grids: Array[Vector2i]) -> bool:
	if not grids.is_empty():
		items.append(item_data)
		item_grids_map[item_data] = grids
		for grid in grids:
			grid_item_map[grid] = item_data
		return true
	return false

func _find_first_availble_grids(item: ItemData) -> Array[Vector2i]:
	var item_shape = item.get_shape()
	for row in rows:
		for col in columns:
			if grid_item_map[Vector2i(col, row)] == null:
				var grids = _try_get_empty_grids_by_shape(Vector2i(col, row), item_shape)
				if not grids.is_empty():
					return grids
	return []

func _try_get_empty_grids_by_shape(start: Vector2i, shape: Vector2i) -> Array[Vector2i]:
	var ret: Array[Vector2i] = []
	for row in shape.y:
		for col in shape.x:
			var grid_id = Vector2i(start.x + col, start.y + row)
			if grid_item_map.has(grid_id) and grid_item_map[grid_id] == null:
				ret.append(grid_id)
			else:
				return []
	return ret


func set_owner_item(item: ItemData) -> void:
	_owner_ref = weakref(item) if item != null else null


func get_owner_item() -> ItemData:
	if _owner_ref == null:
		return null
	return _owner_ref.get_ref() as ItemData
