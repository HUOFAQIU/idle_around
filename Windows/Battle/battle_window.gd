class_name BattleWindow
extends BaseWindow

const CONTAINER_IDS: GDScript = preload("res://Scripts/container_ids.gd")

const SHOW_DEBUG_DISTANCE : bool = false
const FPS_UPDATE_FRAMES : int = 15

@onready var ground_tilemaplayer: TileMapLayer = $Tile/GroundTileMapLayer
@onready var units_root: Node2D = $Tile/Units

@onready var player_health_bar: PlayerHealthBar = $UiOverlay/Control/PlayerHealthBar
@onready var player_regen_bar: PlayerStatusBar = $UiOverlay/Control/PlayerRegenBar
@onready var player_shield_bar: PlayerStatusBar = $UiOverlay/Control/PlayerShieldBar
@onready var player_burn_bar: PlayerStatusBar = $UiOverlay/Control/PlayerBurnBar
@onready var player_poison_bar: PlayerStatusBar = $UiOverlay/Control/PlayerPoisonBar
@onready var info_button: Button = $UiOverlay/Control/GridContainer/InfoButton
@onready var fps_label: Label = $UiOverlay/Control/FpsLabel

var _session : BattleSession
var _map_item : MapItemData
var _map_slot : int = -1
var _battle : BattleManager:
	get:
		return _session.battle if _session != null else null
var _telemetry_adapter : CombatTelemetryAdapter
var _info_log_adapter : BattleLogAdapter
var _console_log_adapter : CombatConsoleAdapter
var _narrator : CombatNarrator
var _fps_frames : int = 0
var _mouse_was_inside : bool = false


func _ready() -> void:
	super()
	title = "战斗窗口"
	player_health_bar.visible = false
	player_regen_bar.visible = false
	player_shield_bar.visible = false
	player_burn_bar.visible = false
	player_poison_bar.visible = false
	$UiOverlay/Control.theme = GameColors.build_label_theme()
	fps_label.add_theme_color_override("font_outline_color", GameColors.to_color(GameColors.TEXT_OUTLINE))
	fps_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.SUCCESS))
	_apply_status_bar_colors()

	info_button.pressed.connect(_on_info_pressed)
	MapBoard.item_removed.connect(_on_map_board_item_removed)

	visibility_changed.connect(_on_visibility_changed)

	_session = BattleSession.new()
	_session.name = "BattleSession"
	add_child(_session)
	_session.units_root = units_root
	_session.map = ground_tilemaplayer
	_session.attach_observers = _attach_battle_observers
	_session.battle_started.connect(_on_battle_started)
	_session.battle_ended.connect(_on_battle_ended)
	_session.player_spawned.connect(_on_player_spawned)

	if SHOW_DEBUG_DISTANCE:
		for cell in ground_tilemaplayer.get_used_cells():
			var label: Label = Label.new()
			label.size = Vector2(10, 10)
			label.add_theme_font_size_override("font_size", 12)

			var center: Vector2 = ground_tilemaplayer.map_to_local(cell)
			label.position = center - label.size / 2.0

			var d : int = Hex.distance(Vector2i(0, 0), cell)
			if d % 2 != 0:
				label.add_theme_color_override("font_color", GameColors.to_color(GameColors.TEXT_PRIMARY))
			else:
				label.add_theme_color_override("font_color", GameColors.to_color(GameColors.TEXT_OUTLINE))
			label.text = str(d)
			ground_tilemaplayer.add_child(label)


func _process(_delta: float) -> void:
	if not visible:
		return

	_fps_frames += 1
	if _fps_frames % FPS_UPDATE_FRAMES != 0:
		return

	var fps := Engine.get_frames_per_second()
	fps_label.text = "FPS %d" % fps
	fps_label.add_theme_color_override("font_color", _fps_color(fps))


func _physics_process(_delta: float) -> void:
	if not visible:
		return

	_update_coord_tooltip()
	_push_scanlines()


func start_map_battle(map_item: MapItemData, slot_index: int = -1) -> void:
	if map_item == null or map_item.map_data == null:
		return
	if not visible:
		open_window()
	_map_item = map_item
	_map_slot = slot_index
	InfoWindow.instance.clear_log()
	_session.player_profile = GameFlow.get_player_profile()
	_session.start(_equipped_souls(), map_item)


func is_battling_slot(slot_index: int) -> bool:
	return visible and _map_slot == slot_index and _map_item != null


func stop_battle() -> void:
	_end_battle()
	_map_item = null
	_map_slot = -1


func _attach_battle_observers(battle: BattleManager) -> void:
	_telemetry_adapter = CombatTelemetryAdapter.new(battle.events)
	_info_log_adapter = BattleLogAdapter.new(battle.events, InfoWindow.instance.append_line)
	_console_log_adapter = CombatConsoleAdapter.new(battle.events)
	_narrator = CombatNarrator.new(battle)


func _on_battle_started(_battle_manager: BattleManager) -> void:
	_set_scanlines(true)


func _on_battle_ended() -> void:
	_telemetry_adapter = null
	_info_log_adapter = null
	_console_log_adapter = null
	_narrator = null
	player_health_bar.visible = false
	player_regen_bar.visible = false
	player_shield_bar.visible = false
	player_burn_bar.visible = false
	player_poison_bar.visible = false
	_set_scanlines(false)


func _on_player_spawned(unit: BattleUnit) -> void:
	player_health_bar.bind(unit.health_attr, unit.max_health_attr, unit.asc)
	player_health_bar.visible = true
	player_regen_bar.bind(unit.asc.get_attribute("regen"), unit.asc)
	player_shield_bar.bind(unit.shield_attr, unit.asc)
	player_burn_bar.bind(unit.asc.get_attribute("burn"), unit.asc)
	player_poison_bar.bind(unit.asc.get_attribute("poison"), unit.asc)


func _end_battle() -> void:
	_session.stop()


func _equipped_souls() -> Array[SoulSlot]:
	var slots : Array[SoulSlot] = []
	var container := ContainerRepository.instance.get_container(CONTAINER_IDS.VESSEL_GRID)
	if container == null:
		return slots
	for vessel in SoulVesselData.combat_vessels_in(container):
		var contents := vessel.ensure_contents()
		var row_slots : Array[SoulSlot] = []
		for soul_item in contents.items:
			if not soul_item is SoulData:
				continue
			var soul := soul_item as SoulData
			var grids := contents.find_grids_by_item_data(soul)
			if grids.is_empty():
				continue
			var column := ContainerData.anchor_of(grids).x
			var slot := SoulSlot.new()
			slot.soul = soul
			slot.vessel = vessel
			slot.container_name = contents.container_name
			slot.column = column
			slot.width = maxi(soul.get_shape().x, 1)
			row_slots.append(slot)
		row_slots.sort_custom(func (a: SoulSlot, b: SoulSlot) -> bool: return a.column < b.column)
		slots.append_array(row_slots)
	return slots


func _push_scanlines() -> void:
	if _battle == null or _battle.player == null:
		return
	for runtime in _battle.player.loadout:
		if runtime != null:
			runtime.refresh_from_ability()


func _set_scanlines(on: bool) -> void:
	var player := _battle.player if _battle != null else null
	if on:
		if player == null:
			return
		for runtime in player.loadout:
			if runtime != null and runtime.soul != null:
				runtime.soul.set_scanline_enabled(runtime.ability != null)
		_push_scanlines()
		return
	if _session == null:
		return
	for soul in _session.souls:
		if soul != null:
			soul.set_scanline_enabled(false)
	if player != null:
		for runtime in player.loadout:
			if runtime != null:
				runtime.clear_display()


func _on_visibility_changed() -> void:
	if not visible:
		if TooltipWindow.instance != null:
			TooltipWindow.instance.hide_tip(self)
		_end_battle()
		_map_item = null
		_map_slot = -1


func _on_map_board_item_removed(slot_index: int) -> void:
	if slot_index == _map_slot:
		hide()


func _on_info_pressed() -> void:
	InfoWindow.instance.toggle()


func _update_coord_tooltip() -> void:
	var tip := TooltipWindow.instance
	if tip == null:
		return

	var manager := PanelManager.instance
	if manager == null or not manager.is_active(self) \
			or manager.get_top_panel_at(get_global_mouse_position()) != self:
		_mouse_was_inside = false
		tip.hide_tip(self)
		return

	var cube_surface := CubeInputSurface.instance
	if cube_surface != null \
			and cube_surface.contains_screen_point(
					get_viewport().get_mouse_position()):
		_mouse_was_inside = false
		tip.hide_tip(self)
		return

	if not _is_mouse_inside():
		if _mouse_was_inside:
			_mouse_was_inside = false
			tip.hide_tip(self)
		return
	_mouse_was_inside = true

	var local_mouse := ground_tilemaplayer.get_local_mouse_position()
	var hovered_cell := ground_tilemaplayer.local_to_map(local_mouse)
	if ground_tilemaplayer.get_cell_source_id(hovered_cell) == -1:
		tip.hide_tip(self)
		return
	tip.show_tip(self, TooltipWindow.Layer.COORD, str(hovered_cell))


func _is_mouse_inside() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


func _apply_status_bar_colors() -> void:
	_apply_status_color(player_regen_bar, "RegenLabel", GameColors.REGEN)
	_apply_status_color(player_shield_bar, "ShieldLabel", GameColors.SHIELD)
	_apply_status_color(player_burn_bar, "BurnLabel", GameColors.BURN)
	_apply_status_color(player_poison_bar, "PoisonLabel", GameColors.POISON)


func _apply_status_color(bar: PlayerStatusBar, label_name: String, hex: String) -> void:
	var color := GameColors.to_color(hex)
	bar.fill_color = color
	var label := bar.get_node_or_null(label_name) as Label
	if label != null:
		label.add_theme_color_override("font_color", color)


func _fps_color(fps : float) -> Color:
	if fps >= 55:
		return GameColors.to_color(GameColors.SUCCESS)
	if fps >= 30:
		return GameColors.to_color(GameColors.WARNING)
	return GameColors.to_color(GameColors.DANGER)


func get_battle_session() -> BattleSession:
	return _session


func get_battle() -> BattleManager:
	return _battle


func spawn_monster_for_test(monster_id : StringName) -> bool:
	return _session.spawn_monster_for_test(monster_id)


func get_test_state() -> Dictionary:
	if _session == null:
		return {
			"running": false,
			"elapsed": 0.0,
			"player": {},
			"enemies": [],
			"player_souls": [],
			"map_id": "",
			"map_finished": false,
			"map": {},
			"map_kills": {},
			"pending_spawns": 0,
		}
	return _session.get_state()


func get_fps_text_for_test() -> String:
	return fps_label.text
