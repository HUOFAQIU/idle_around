class_name SaveSlotsContent
extends FaceContent
## 面 01 内容：6 个存档位 + 新游戏入口。
##
## 只负责显示和转交点击；读档/新游戏/删档/满槽提示由 GameFlow 决定。
## 槽位摘要通过 set_slots() 注入，避免面内容直接依赖 SaveManager。

signal new_game_requested
signal slot_requested(slot: int)
signal delete_requested(slot: int)

const SLOT_COUNT: int = SaveStorage.SLOT_COUNT

var _slot_entries: Array[SaveSlotEntry] = []

@onready var _new_game_button: Button = $Grid/NewGameButton


func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	for index in SLOT_COUNT:
		var entry := get_node("Grid/Slot%d" % (index + 1)) as SaveSlotEntry
		_slot_entries.append(entry)
		entry.slot_requested.connect(_on_slot_pressed.bind(index))
		entry.delete_requested.connect(_on_slot_delete_pressed.bind(index))
		entry.delete_confirmation_started.connect(
				_on_delete_confirmation_started.bind(index))
	set_slots([])


func content_id() -> StringName:
	return &"save_slots"


## slots 为 GameFlow.get_slot_summaries()：slot / occupied / character_name / active
func set_slots(slots: Array) -> void:
	for index in _slot_entries.size():
		var occupied := false
		var character_name := ""
		var active := false
		if index < slots.size():
			var entry: Dictionary = slots[index]
			occupied = bool(entry.get("occupied", false))
			character_name = String(entry.get("character_name", ""))
			active = bool(entry.get("active", false))
		_slot_entries[index].set_slot(index, occupied, character_name, active)


## 测试/调试：走与鼠标点击相同的按钮信号
func activate_new_game() -> void:
	_new_game_button.pressed.emit()


func activate_slot(slot: int) -> bool:
	if slot < 0 or slot >= _slot_entries.size():
		return false
	return _slot_entries[slot].activate()


## 删除是两段式：第一次进入确认，第二次才发 delete_requested；活动槽返回 false
func activate_delete(slot: int) -> bool:
	if slot < 0 or slot >= _slot_entries.size():
		return false
	return _slot_entries[slot].activate_delete()


func _cancel_delete_confirmations(except_slot: int = -1) -> void:
	for index in _slot_entries.size():
		if index != except_slot:
			_slot_entries[index].set_confirming(false)


func _on_new_game_pressed() -> void:
	_cancel_delete_confirmations()
	new_game_requested.emit()


func _on_slot_pressed(slot: int) -> void:
	_cancel_delete_confirmations()
	slot_requested.emit(slot)


func _on_slot_delete_pressed(slot: int) -> void:
	delete_requested.emit(slot)


func _on_delete_confirmation_started(slot: int) -> void:
	_cancel_delete_confirmations(slot)
