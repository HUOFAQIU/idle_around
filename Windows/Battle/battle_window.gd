class_name BattleWindow
extends BaseWindow

@onready var battle_arena: BattleArena = $BattleArena

var _map_item: MapItemData
var _map_slot: int = -1
var _session: BattleSession
var _battle: BattleManager:
	get:
		return _session.battle if _session != null else null


func _ready() -> void:
	super()
	title = "战斗窗口"

	var log_btn := Button.new()
	log_btn.name = "LogButton"
	log_btn.text = "日志"
	log_btn.tooltip_text = "打开/关闭战斗日志"
	log_btn.pressed.connect(_on_info_pressed)
	add_title_bar_button(log_btn)

	if battle_arena != null:
		battle_arena.battle_logged.connect(_on_battle_logged)

	MapBoard.item_removed.connect(_on_map_board_item_removed)
	visibility_changed.connect(_on_visibility_changed)


func start_battle(map_item: MapItemData, slot_index: int = -1) -> void:
	if map_item == null or map_item.map_data == null:
		return
	if not visible:
		_open_window()
	_map_item = map_item
	_map_slot = slot_index
	if InfoWindow.instance != null:
		InfoWindow.instance.clear_log()
		InfoWindow.instance.append_line("[战斗] 进入地图：%s" % map_item.map_data.display_name)
	if battle_arena != null:
		if map_item.map_data.weather_preset != null:
			battle_arena.set_weather_preset(map_item.map_data.weather_preset)
		battle_arena.start_run(map_item.map_data)


func is_battling_slot(slot_index: int) -> bool:
	return visible and _map_slot == slot_index and _map_item != null


func stop_battle() -> void:
	_map_item = null
	_map_slot = -1
	if battle_arena != null:
		battle_arena.paused = true


func get_battle_session() -> BattleSession:
	return _session


func get_battle() -> BattleManager:
	return _battle


func spawn_monster_for_test(monster_id: StringName) -> bool:
	if _session != null:
		return _session.spawn_monster_for_test(monster_id)
	return false


func get_fps_text_for_test() -> String:
	return "FPS %d" % int(Engine.get_frames_per_second())


func _on_battle_logged(line: String) -> void:
	if InfoWindow.instance != null:
		InfoWindow.instance.append_line(line)


func _on_info_pressed() -> void:
	if InfoWindow.instance != null:
		InfoWindow.instance.toggle()


func _on_map_board_item_removed(slot_index: int) -> void:
	if slot_index == _map_slot:
		hide()


func _on_visibility_changed() -> void:
	if not visible:
		if TooltipWindow.instance != null:
			TooltipWindow.instance.hide_tip(self)
		_map_item = null
		_map_slot = -1
