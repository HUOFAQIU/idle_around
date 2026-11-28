class_name BattleWindow
extends BaseWindow

const ARENA_SCENE_PATH := "res://windows/Battle/scenes/battle_arena.tscn"

var battle_arena: BattleArena
var _arena_preload_requested: bool = false
var _map_item: MapItemData
var _map_slot: int = -1
var _session: BattleSession:
	get:
		return battle_arena.get_battle_session() if battle_arena != null else null
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

	MapBoard.item_removed.connect(_on_map_board_item_removed)
	visibility_changed.connect(_on_visibility_changed)
	_begin_arena_preload.call_deferred()


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
	var equipped_slots := _collect_equipped_soul_slots()
	var arena := _ensure_arena()
	if arena != null:
		if map_item.map_data.weather_preset != null:
			arena.set_weather_preset(map_item.map_data.weather_preset)
		arena.start_run(map_item, equipped_slots)


func is_battling_slot(slot_index: int) -> bool:
	return visible and _map_slot == slot_index and _map_item != null


func stop_battle() -> void:
	_map_item = null
	_map_slot = -1
	if battle_arena != null:
		battle_arena.stop_run()


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


func _begin_arena_preload() -> void:
	if _arena_preload_requested or battle_arena != null:
		return
	if ResourceLoader.load_threaded_request(ARENA_SCENE_PATH) == OK:
		_arena_preload_requested = true


func _ensure_arena() -> BattleArena:
	if battle_arena != null:
		return battle_arena
	var packed: PackedScene = null
	if _arena_preload_requested:
		packed = ResourceLoader.load_threaded_get(ARENA_SCENE_PATH) as PackedScene
		_arena_preload_requested = false
	if packed == null:
		packed = load(ARENA_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	battle_arena = packed.instantiate() as BattleArena
	if battle_arena == null:
		return null
	battle_arena.name = "BattleArena"
	battle_arena.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_root.add_child(battle_arena)
	battle_arena.battle_logged.connect(_on_battle_logged)
	return battle_arena


func _on_battle_logged(line: String, color: String = "white") -> void:
	if InfoWindow.instance != null:
		InfoWindow.instance.append_line(line, color)


func _on_info_pressed() -> void:
	if InfoWindow.instance != null:
		InfoWindow.instance.toggle()


func _on_map_board_item_removed(slot_index: int) -> void:
	if slot_index == _map_slot:
		hide()


func _on_visibility_changed() -> void:
	if visible:
		_ensure_arena()
		return
	TooltipService.hide_tip(self)
	if battle_arena != null:
		battle_arena.stop_run()
	_map_item = null
	_map_slot = -1


func _collect_equipped_soul_slots() -> Array[SoulSlot]:
	var result: Array[SoulSlot] = []
	if ContainerRepository.instance == null:
		return result
	var grid := ContainerRepository.instance.get_container(ContainerIds.VESSEL_GRID)
	if grid == null:
		return result
	for vessel in SoulVesselData.combat_vessels_in(grid):
		var contents := vessel.ensure_contents()
		for item in contents.items:
			if not (item is SoulData):
				continue
			var soul := item as SoulData
			var grids := contents.find_grids_by_item_data(soul)
			var anchor := ContainerData.anchor_of(grids) if not grids.is_empty() else Vector2i.ZERO
			var slot := SoulSlot.new()
			slot.soul = soul
			slot.vessel = vessel
			slot.container_name = contents.container_name
			slot.column = anchor.x
			slot.width = maxi(soul.get_shape().x, 1)
			result.append(slot)
	return result
