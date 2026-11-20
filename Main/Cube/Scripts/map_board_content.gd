class_name MapBoardContent
extends FaceContent
## 05 面内容：8 个地图按钮 + 中心投放槽。
##
## 只负责显示和交互：地图板状态在 MapBoard，战斗窗口由 main.gd 打开。
## 槽位 0..7 从左上角起顺时针，对应 3×3 网格的 0,1,2,5,8,7,6,3。

signal battle_requested(slot_index: int)
signal toast_requested(text: String)

## 槽位下标 → 3×3 网格的 Cell 下标
const SLOT_TO_CELL: Array[int] = [0, 1, 2, 5, 8, 7, 6, 3]
const DEFAULT_ACCENT: Color = Color("#4fb8ff")

var _accent_color: Color = DEFAULT_ACCENT
var _slot_entries: Array[MapSlotEntry] = []
## 上一帧显示的槽位内容，用来只在“从空变有”时播放弹出动画
var _displayed: Array[MapItemData] = []
var _auto_placing: bool = false

@onready var _drop_slot: MapDropSlot = $Grid/Cell4


func _ready() -> void:
	_displayed.resize(MapBoard.SLOT_COUNT)
	for slot_index in SLOT_TO_CELL.size():
		var cell_index := SLOT_TO_CELL[slot_index]
		var entry := get_node("Grid/Cell%d" % cell_index) as MapSlotEntry
		_slot_entries.append(entry)
		entry.pressed.connect(_on_map_pressed.bind(slot_index))
		entry.eject_requested.connect(_on_map_eject_requested.bind(slot_index))
		entry.set_accent(_accent_color)
	_drop_slot.clicked.connect(_on_drop_slot_clicked)
	_drop_slot.set_accent(_accent_color)
	MapBoard.board_changed.connect(_rebuild)
	_rebuild()


func setup(index: int, display_name: String, accent: Color) -> void:
	super.setup(index, display_name, accent)
	_accent_color = accent
	for entry in _slot_entries:
		entry.set_accent(accent)
	if is_node_ready() and _drop_slot != null:
		_drop_slot.set_accent(accent)


func content_id() -> StringName:
	return &"map_board"


## 测试/调试：模拟点击某个地图按钮
func activate_map_button(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _slot_entries.size():
		return false
	return _slot_entries[slot_index].activate()


## 测试/调试：模拟点击某个地图按钮右上角 ⬇
func activate_eject(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _slot_entries.size():
		return false
	return _slot_entries[slot_index].activate_eject()


## 测试/调试：模拟点击中心投放槽
func activate_drop_slot() -> void:
	_drop_slot.activate()


func _rebuild() -> void:
	if not is_node_ready():
		return
	for slot_index in SLOT_TO_CELL.size():
		var item := MapBoard.get_slot(slot_index)
		var was_empty := _displayed[slot_index] == null
		_slot_entries[slot_index].set_map(item)
		if item != null and was_empty:
			_slot_entries[slot_index].play_appear()
		_displayed[slot_index] = item
	_drop_slot.set_pending(MapBoard.get_pending())
	if MapBoard.get_pending() != null and MapBoard.can_place() and not _auto_placing:
		call_deferred("_auto_place_pending")


## 中心槽有地图且空出位置时，自动飞进第一个空槽
func _auto_place_pending() -> void:
	if _auto_placing:
		return
	_auto_placing = true
	var result := MapBoard.settle_pending()
	_auto_placing = false
	if result.status == MapPlaceResult.Status.PLACED:
		_play_fly_animation(result.item, result.slot_index)


func _on_drop_slot_clicked() -> void:
	var moving := GBIS.moving_item_service
	if moving.is_dragging():
		var item := moving.moving_item
		if item is MapItemData:
			_try_place_map(item as MapItemData)
		return
	var pending := MapBoard.get_pending()
	if pending == null:
		return
	MapBoard.take_pending()
	moving.begin_detached(pending, Vector2i.ZERO, MapDropSlot.ITEM_BASE_SIZE)


## 手上有地图时点中心槽：有空格就放按钮，满了就留在中心槽
func _try_place_map(item: MapItemData) -> void:
	var moving := GBIS.moving_item_service
	var result := MapBoard.submit(item)
	match result.status:
		MapPlaceResult.Status.PLACED:
			moving.finish()
			_play_fly_animation(result.item, result.slot_index)
		MapPlaceResult.Status.QUEUED:
			moving.finish()
			toast_requested.emit("地图集已满")
		MapPlaceResult.Status.REJECTED:
			toast_requested.emit("地图集已满")


func _on_map_pressed(slot_index: int) -> void:
	battle_requested.emit(slot_index)


func _on_map_eject_requested(slot_index: int) -> void:
	if not MapBoard.eject(slot_index):
		toast_requested.emit("仓库已满，无法退回")


## 中心槽的小卡面飞向按钮并缩小消失；状态已经先写入 MapBoard
func _play_fly_animation(item: MapItemData, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_entries.size():
		return
	var entry := _slot_entries[slot_index]
	var flying := ItemView.new(item, MapDropSlot.ITEM_BASE_SIZE)
	flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flying.z_index = 50
	add_child(flying)
	var origin := get_global_rect().position
	var start := _drop_slot.get_global_rect().position - origin
	start += (_drop_slot.size - flying.size) * 0.5
	var target := entry.get_global_rect().position - origin
	target += (entry.size - flying.size) * 0.5
	flying.position = start
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(flying, "position", target, 0.18)
	tween.tween_property(flying, "scale", Vector2(0.35, 0.35), 0.18)
	tween.tween_property(flying, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(flying.queue_free)
