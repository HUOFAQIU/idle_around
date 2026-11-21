extends Node3D

const STARTUP_TIMING: GDScript = preload("res://Scripts/debug/startup_timing.gd")

@onready var _cube_rig: CubeRig = get_node(CubeScenePaths.RIG)
@onready var _hud: CubeHud = $HUD
@onready var _game_ui: GameUI = $GameUI/GameControl
@onready var _save_slots: SaveSlotsContent = get_node(CubeScenePaths.SAVE_SLOTS)
@onready var _character_select: CharacterSelectContent = get_node(
		CubeScenePaths.CHARACTER_SELECT)
@onready var _pet_menu: PetPanelContent = get_node(CubeScenePaths.PET_MENU)
@onready var _map_board: MapBoardContent = get_node(CubeScenePaths.MAP_BOARD)
@onready var _placement: CubePlacement = $CubePlacement


func _ready() -> void:
	_cube_rig.face_identified.connect(_on_face_identified)
	_cube_rig.setup_placement(_placement)
	_pet_menu.panel_requested.connect(_game_ui.open_panel)
	_map_board.battle_requested.connect(_on_map_battle_requested)
	_map_board.toast_requested.connect(_on_toast_requested)
	_save_slots.new_game_requested.connect(GameFlow.request_new_game)
	_save_slots.slot_requested.connect(GameFlow.request_load_slot)
	_save_slots.delete_requested.connect(GameFlow.request_delete_slot)
	_save_slots.quit_requested.connect(_on_quit_requested)
	_character_select.character_requested.connect(GameFlow.create_new_game)
	GameFlow.state_changed.connect(_on_flow_state_changed)
	GameFlow.slots_changed.connect(_refresh_slots)
	GameFlow.face_focus_requested.connect(_on_face_focus_requested)
	GameFlow.toast_requested.connect(_on_toast_requested)
	GameFlow.session_will_change.connect(_on_session_will_change)
	_placement.apply_now()
	_refresh_slots()
	_apply_face_locks()
	STARTUP_TIMING.mark("主场景就绪")
	await RenderingServer.frame_post_draw
	STARTUP_TIMING.mark("首帧绘制")


func _on_face_identified(
		face_index: int,
		face_name: String,
		accent_color: Color,
) -> void:
	print("[立方体] 点击面 %d：%s" % [face_index + 1, face_name])
	_hud.show_face_identified(face_name, accent_color)


func _on_flow_state_changed(_state: int) -> void:
	_apply_face_locks()


func _refresh_slots() -> void:
	_save_slots.set_slots(GameFlow.get_slot_summaries())


func _apply_face_locks() -> void:
	for face in _cube_rig.get_faces():
		face.set_locked(GameFlow.get_face_lock_state(face.face_index))


func _on_face_focus_requested(face_index: int) -> void:
	_cube_rig.flip_to_face(face_index)


func _on_map_battle_requested(slot_index: int) -> void:
	var map_item := MapBoard.get_slot(slot_index)
	if map_item == null:
		return
	var battle := _game_ui.battle_window
	if battle.is_battling_slot(slot_index):
		_game_ui.panel_manager.raise(battle)
		return
	battle.start_map_battle(map_item, slot_index)
	_game_ui.panel_manager.raise(battle)


func _on_toast_requested(text: String) -> void:
	_hud.show_near_cube(text)


func _on_session_will_change() -> void:
	_game_ui.close_all_panels()
	_game_ui.battle_window.stop_battle()


func _on_quit_requested() -> void:
	SaveManager.save_now()
	get_tree().quit()
