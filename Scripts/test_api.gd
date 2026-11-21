class_name TestAPI
extends RefCounted

const CONTAINER_IDS: GDScript = preload("res://Scripts/container_ids.gd")
const BURN_APPLY : GameplayEffect = preload("res://base_mods/core/effects/burn_apply.tres")
const BURN_TICK : GameplayEffect = preload("res://base_mods/core/effects/burn_tick.tres")
const POISON_APPLY : GameplayEffect = preload("res://base_mods/core/effects/poison_apply.tres")
const POISON_TICK : GameplayEffect = preload("res://base_mods/core/effects/poison_tick.tres")
const REGEN_APPLY : GameplayEffect = preload("res://base_mods/core/effects/regen_apply.tres")
const REGEN_TICK : GameplayEffect = preload("res://base_mods/core/effects/regen_tick.tres")
const FREEZE_UNIT : GameplayEffect = preload("res://base_mods/core/effects/freeze_unit.tres")
const GAME_COLORS_SCRIPT : GDScript = preload("res://Scripts/game_colors.gd")
const GAME_COLOR_CATALOG : GDScript = preload("res://Scripts/game_color_catalog.gd")

const INVENTORY: GDScript = preload("res://Scripts/test_api/inventory.gd")
const MAP: GDScript = preload("res://Scripts/test_api/map.gd")
const SAVE: GDScript = preload("res://Scripts/test_api/save.gd")
const MOD: GDScript = preload("res://Scripts/test_api/mod.gd")
const WINDOW: GDScript = preload("res://Scripts/test_api/window.gd")
const CUBE: GDScript = preload("res://Scripts/test_api/cube.gd")
const COLORS: GDScript = preload("res://Scripts/test_api/colors.gd")
const TERMINAL: GDScript = preload("res://Scripts/test_api/terminal.gd")
const BATTLE: GDScript = preload("res://Scripts/test_api/battle.gd")
const DEBUG: GDScript = preload("res://Scripts/test_api/debug.gd")


static func add_soul(id : StringName, container : String = "") -> bool:
	return INVENTORY.add_soul(id, container)


static func has_container(container: String) -> bool:
	return INVENTORY.has_container(container)


static func get_container_names() -> PackedStringArray:
	return INVENTORY.get_container_names()


static func add_soul_to_warehouse(id : StringName) -> bool:
	return INVENTORY.add_soul_to_warehouse(id)


static func show_shop() -> bool:
	return INVENTORY.show_shop()


static func shop_add_soul(id : StringName) -> bool:
	return INVENTORY.shop_add_soul(id)


static func pick_up_item(container : String, grid_id : Vector2i) -> bool:
	return INVENTORY.pick_up_item(container, grid_id)


static func cancel_moving_item() -> bool:
	return INVENTORY.cancel_moving_item()


static func drop_moving_item(container : String, grid_id : Vector2i) -> bool:
	return INVENTORY.drop_moving_item(container, grid_id)


static func sell_moving_item() -> bool:
	return INVENTORY.sell_moving_item()


static func quick_sell(container : String, grid_id : Vector2i) -> bool:
	return INVENTORY.quick_sell(container, grid_id)


static func set_warehouse_page(page : int) -> bool:
	return INVENTORY.set_warehouse_page(page)


static func get_warehouse_page() -> int:
	return INVENTORY.get_warehouse_page()


static func add_vessel(id : StringName, container : String = "") -> bool:
	return INVENTORY.add_vessel(id, container)


static func equip_vessel(id : StringName) -> bool:
	return INVENTORY.equip_vessel(id)


static func vessel_add_soul(soul_id : StringName, vessel_slot : int = 0) -> bool:
	return INVENTORY.vessel_add_soul(soul_id, vessel_slot)


static func get_vessel_contents(vessel_slot : int = 0) -> Array[String]:
	return INVENTORY.get_vessel_contents(vessel_slot)


static func get_vessel_ids() -> Array[StringName]:
	return INVENTORY.get_vessel_ids()


static func get_equipped_vessel_tooltip_text(vessel_slot : int = 0) -> String:
	return INVENTORY.get_equipped_vessel_tooltip_text(vessel_slot)


static func get_equipped_vessel_tooltip_bbcode(vessel_slot : int = 0) -> String:
	return INVENTORY.get_equipped_vessel_tooltip_bbcode(vessel_slot)


static func get_equipped_vessel_tooltip_ansi(vessel_slot : int = 0) -> String:
	return INVENTORY.get_equipped_vessel_tooltip_ansi(vessel_slot)


static func clear_container(container : String) -> void:
	INVENTORY.clear_container(container)


static func get_container_items(container : String) -> Array[String]:
	return INVENTORY.get_container_items(container)


static func validate_container_ids() -> Array[String]:
	return INVENTORY.validate_container_ids()


static func set_unlock_all(enabled : bool) -> void:
	INVENTORY.set_unlock_all(enabled)


static func unlock_all_collection() -> bool:
	return INVENTORY.unlock_all_collection()


static func get_seen_ids(kind : int) -> Array[StringName]:
	return INVENTORY.get_seen_ids(kind)


static func is_seen(kind : int, id : StringName) -> bool:
	return INVENTORY.is_seen(kind, id)


static func get_soul_ids() -> Array[StringName]:
	return INVENTORY.get_soul_ids()


static func get_soul_types(id : StringName) -> Array[StringName]:
	return INVENTORY.get_soul_types(id)


static func get_soul_tags(id : StringName) -> Array[StringName]:
	return INVENTORY.get_soul_tags(id)


static func get_soul_size_tag(id : StringName) -> StringName:
	return INVENTORY.get_soul_size_tag(id)


static func get_vessel_tooltip_text(id : StringName) -> String:
	return INVENTORY.get_vessel_tooltip_text(id)


static func get_vessel_tooltip_bbcode(id : StringName) -> String:
	return INVENTORY.get_vessel_tooltip_bbcode(id)


static func get_vessel_tooltip_ansi(id : StringName) -> String:
	return INVENTORY.get_vessel_tooltip_ansi(id)


static func get_skill_tags() -> Array[Dictionary]:
	return INVENTORY.get_skill_tags()


static func get_soul_card_info(id : StringName) -> Dictionary:
	return INVENTORY.get_soul_card_info(id)


static func get_soul_damage_scaling(id : StringName) -> Dictionary:
	return INVENTORY.get_soul_damage_scaling(id)


static func get_equipped_soul_damage_preview(id : StringName) -> Dictionary:
	return INVENTORY.get_equipped_soul_damage_preview(id)


static func get_soul_steps(id : StringName) -> Array[Dictionary]:
	return INVENTORY.get_soul_steps(id)


static func get_soul_cast_times(id : StringName) -> int:
	return INVENTORY.get_soul_cast_times(id)


static func get_soul_tooltip_text(id : StringName) -> String:
	return INVENTORY.get_soul_tooltip_text(id)


static func get_soul_tooltip_bbcode(id : StringName) -> String:
	return INVENTORY.get_soul_tooltip_bbcode(id)


static func get_soul_tooltip_ansi(id : StringName) -> String:
	return INVENTORY.get_soul_tooltip_ansi(id)


static func get_equipped_soul_tooltip_text(id : StringName) -> String:
	return INVENTORY.get_equipped_soul_tooltip_text(id)


static func get_equipped_soul_tooltip_bbcode(id : StringName) -> String:
	return INVENTORY.get_equipped_soul_tooltip_bbcode(id)


static func get_equipped_soul_tooltip_ansi(id : StringName) -> String:
	return INVENTORY.get_equipped_soul_tooltip_ansi(id)


static func get_monster_ids() -> Array[StringName]:
	return INVENTORY.get_monster_ids()


static func get_monster_spawn_distances(id : StringName) -> Array[int]:
	return INVENTORY.get_monster_spawn_distances(id)


static func get_map_ids() -> Array[StringName]:
	return MAP.get_map_ids()


static func validate_maps() -> Array[String]:
	return MAP.validate_maps()


static func add_map_to_warehouse(map_id : StringName = MapCatalog.FOREST_MAP_ID) -> bool:
	return MAP.add_map_to_warehouse(map_id)


static func add_quantity_stone_to_warehouse() -> bool:
	return MAP.add_quantity_stone_to_warehouse()


static func get_map_board_state() -> Dictionary:
	return MAP.get_map_board_state()


static func add_map_to_board(
	map_id : StringName = MapCatalog.FOREST_MAP_ID,
	slot_index : int = -1
) -> int:
	return MAP.add_map_to_board(map_id, slot_index)


static func submit_map_to_board(map_id : StringName = MapCatalog.FOREST_MAP_ID) -> Dictionary:
	return MAP.submit_map_to_board(map_id)


static func settle_pending_map() -> Dictionary:
	return MAP.settle_pending_map()


static func eject_map_from_board(slot_index : int) -> bool:
	return MAP.eject_map_from_board(slot_index)


static func start_map_battle_from_board(slot_index : int) -> bool:
	return MAP.start_map_battle_from_board(slot_index)


static func click_map_drop_slot() -> bool:
	return MAP.click_map_drop_slot()


static func save_now() -> bool:
	return SAVE.save_now()


static func load_save_slot(slot: int) -> bool:
	return SAVE.load_save_slot(slot)


static func load_save_slot_raw(slot: int) -> bool:
	return SAVE.load_save_slot_raw(slot)


static func new_game(character_id: StringName = &"small_coal_lamp") -> bool:
	return SAVE.new_game(character_id)


static func delete_save_slot(slot: int) -> bool:
	return SAVE.delete_save_slot(slot)


static func has_save() -> bool:
	return SAVE.has_save()


static func get_save_slots() -> Array[Dictionary]:
	return SAVE.get_save_slots()


static func get_active_slot() -> int:
	return SAVE.get_active_slot()


static func get_game_flow_state() -> Dictionary:
	return SAVE.get_game_flow_state()


static func get_save_path(slot: int) -> String:
	return SAVE.get_save_path(slot)


static func get_save_status() -> Dictionary:
	return SAVE.get_save_status()


static func dump_save() -> Dictionary:
	return SAVE.dump_save()


static func check_save_pipeline() -> Dictionary:
	return SAVE.check_save_pipeline()


static func get_mod_list() -> Array[Dictionary]:
	return MOD.get_mod_list()


static func get_mod_errors() -> Array[String]:
	return MOD.get_mod_errors()


static func get_mod_warnings() -> Array[String]:
	return MOD.get_mod_warnings()


static func is_builtin_mod(mod_id : StringName) -> bool:
	return MOD.is_builtin_mod(mod_id)


static func get_mod_content_ids(mod_id : StringName) -> Dictionary:
	return MOD.get_mod_content_ids(mod_id)


static func validate_core_manifest() -> Array[String]:
	return MOD.validate_core_manifest()


static func get_mod_cues() -> Array[Dictionary]:
	return MOD.get_mod_cues()


static func is_mod_cue_registered(tag : StringName) -> bool:
	return MOD.is_mod_cue_registered(tag)


static func show_mod_window() -> bool:
	return MOD.show_mod_window()


static func get_mod_window_state() -> Dictionary:
	return MOD.get_mod_window_state()


static func get_mod_load_order() -> Array[StringName]:
	return MOD.get_mod_load_order()


static func get_mod_order() -> Array[StringName]:
	return MOD.get_mod_order()


static func set_mod_order(ids : Array[StringName]) -> bool:
	return MOD.set_mod_order(ids)


static func set_mod_enabled(mod_id : StringName, enabled : bool) -> bool:
	return MOD.set_mod_enabled(mod_id, enabled)


static func get_orphaned_records() -> Array[Dictionary]:
	return MOD.get_orphaned_records()


static func set_window_pinned(window_name : String, pinned : bool) -> bool:
	return WINDOW.set_window_pinned(window_name, pinned)


static func is_window_pinned(window_name : String) -> bool:
	return WINDOW.is_window_pinned(window_name)


static func get_window_pin_states() -> Dictionary:
	return WINDOW.get_window_pin_states()


static func get_cube_screen_position() -> Vector2:
	return WINDOW.get_cube_screen_position()


static func set_cube_screen_position(target_position : Vector2) -> bool:
	return WINDOW.set_cube_screen_position(target_position)


static func get_active_panel_name() -> String:
	return WINDOW.get_active_panel_name()


static func get_visible_panel_rects() -> Array[Rect2]:
	return WINDOW.get_visible_panel_rects()


static func set_cube_passthrough_enabled(enabled : bool) -> bool:
	return CUBE.set_cube_passthrough_enabled(enabled)


static func is_cube_passthrough_enabled() -> bool:
	return CUBE.is_cube_passthrough_enabled()


static func get_cube_passthrough_state() -> Dictionary:
	return CUBE.get_cube_passthrough_state()


static func get_cube_state() -> Dictionary:
	return CUBE.get_cube_state()


static func get_cube_layering_state() -> Dictionary:
	return CUBE.get_cube_layering_state()


static func set_cube_face_front(face_index : int) -> bool:
	return CUBE.set_cube_face_front(face_index)


static func get_cube_face_content(face_index : int) -> String:
	return CUBE.get_cube_face_content(face_index)


static func get_cube_face_number(face_index : int) -> String:
	return CUBE.get_cube_face_number(face_index)


static func get_cube_face_lock_state(face_index : int) -> bool:
	return CUBE.get_cube_face_lock_state(face_index)


static func click_cube_face_button(face_index : int) -> bool:
	return CUBE.click_cube_face_button(face_index)


static func click_cube_new_game() -> bool:
	return CUBE.click_cube_new_game()


static func click_cube_quit() -> bool:
	return CUBE.click_cube_quit()


static func click_cube_save_slot(slot: int) -> bool:
	return CUBE.click_cube_save_slot(slot)


static func click_cube_delete_save_slot(slot: int) -> bool:
	return CUBE.click_cube_delete_save_slot(slot)


static func click_cube_character(character_id: StringName) -> bool:
	return CUBE.click_cube_character(character_id)


static func click_cube_pet_button(panel_id: StringName) -> bool:
	return CUBE.click_cube_pet_button(panel_id)


static func get_game_color(constant_name : String) -> String:
	return COLORS.get_game_color(constant_name)


static func get_color_catalog() -> Dictionary:
	return COLORS.get_color_catalog()


static func validate_color_groups() -> Array[String]:
	return COLORS.validate_color_groups()


static func terminal_write_line(text : String) -> bool:
	return TERMINAL.terminal_write_line(text)


static func terminal_write_ansi(text : String) -> bool:
	return TERMINAL.terminal_write_ansi(text)


static func terminal_set_content(text : String) -> bool:
	return TERMINAL.terminal_set_content(text)


static func terminal_set_ansi_content(text : String) -> bool:
	return TERMINAL.terminal_set_ansi_content(text)


static func terminal_scroll(lines : int) -> bool:
	return TERMINAL.terminal_scroll(lines)


static func terminal_scroll_to_bottom() -> bool:
	return TERMINAL.terminal_scroll_to_bottom()


static func terminal_clear() -> bool:
	return TERMINAL.terminal_clear()


static func terminal_set_grid(enabled: bool) -> bool:
	return TERMINAL.terminal_set_grid(enabled)


static func terminal_snapshot() -> Dictionary:
	return TERMINAL.terminal_snapshot()


static func complete_command(line : String, caret : int = -1) -> Dictionary:
	return TERMINAL.complete_command(line, caret)


static func tooltip_snapshot() -> Dictionary:
	return TERMINAL.tooltip_snapshot()


static func show_terminal() -> bool:
	return TERMINAL.show_terminal()


static func is_terminal_open() -> bool:
	return TERMINAL.is_terminal_open()


static func terminal_show_soul_tooltip(
	id : StringName, equipped : bool = false, grid : bool = true
) -> bool:
	return TERMINAL.terminal_show_soul_tooltip(id, equipped, grid)


static func terminal_show_vessel_tooltip(id : StringName, grid : bool = true) -> bool:
	return TERMINAL.terminal_show_vessel_tooltip(id, grid)


static func terminal_show_equipped_vessel_tooltip(
	slot : int = 0, grid : bool = true
) -> bool:
	return TERMINAL.terminal_show_equipped_vessel_tooltip(slot, grid)


static func start_battle(map_id : StringName = MapCatalog.FOREST_MAP_ID) -> bool:
	return BATTLE.start_battle(map_id)


static func stop_battle() -> void:
	BATTLE.stop_battle()


static func spawn_monster(monster_id : StringName) -> bool:
	return BATTLE.spawn_monster(monster_id)


static func apply_burn(target : String = "player") -> bool:
	return BATTLE.apply_burn(target)


static func apply_poison(target : String = "player") -> bool:
	return BATTLE.apply_poison(target)


static func apply_regen(target : String = "player") -> bool:
	return BATTLE.apply_regen(target)


static func apply_freeze(target : String = "player", seconds : float = 3.0) -> bool:
	return BATTLE.apply_freeze(target, seconds)


static func play_claw_cue(target : String = "enemy", direction : int = 1) -> bool:
	return BATTLE.play_claw_cue(target, direction)


static func apply_soul_freeze(soul_name : String, seconds : float = 1.0, target : String = "player") -> bool:
	return BATTLE.apply_soul_freeze(soul_name, seconds, target)


static func simulate_soul_used(soul_name : String, target : String = "player") -> bool:
	return BATTLE.simulate_soul_used(soul_name, target)


static func charge_soul(soul_name : String, seconds : float, target : String = "player") -> bool:
	return BATTLE.charge_soul(soul_name, seconds, target)


static func damage_unit(target : String = "player", amount : float = 1.0) -> bool:
	return BATTLE.damage_unit(target, amount)


static func has_status(tag : StringName, target : String = "player") -> bool:
	return BATTLE.has_status(tag, target)


static func get_battle_state() -> Dictionary:
	return BATTLE.get_battle_state()


static func get_battle_tick() -> int:
	return BATTLE.get_battle_tick()


static func pause_battle() -> bool:
	return BATTLE.pause_battle()


static func resume_battle() -> bool:
	return BATTLE.resume_battle()


static func step_battle(ticks : int = 1) -> bool:
	return BATTLE.step_battle(ticks)


static func get_battle_clock() -> Dictionary:
	return BATTLE.get_battle_clock()


static func get_enemy_count() -> int:
	return BATTLE.get_enemy_count()


static func get_nearest_enemy_distance() -> float:
	return BATTLE.get_nearest_enemy_distance()


static func get_enemies_in_attack_range() -> int:
	return BATTLE.get_enemies_in_attack_range()


static func get_perf_snapshot() -> Dictionary:
	return BATTLE.get_perf_snapshot()


static func get_battle_log() -> String:
	return BATTLE.get_battle_log()


static func get_fps_text() -> String:
	return BATTLE.get_fps_text()


static func get_debug_events(category : String = "", limit : int = 200) -> Array:
	return DEBUG.get_debug_events(category, limit)


static func get_debug_stats() -> Dictionary:
	return DEBUG.get_debug_stats()


static func get_debug_snapshot() -> Dictionary:
	return DEBUG.get_debug_snapshot()


static func get_soul_runtime(soul_name : String, target : String = "player") -> Dictionary:
	return DEBUG.get_soul_runtime(soul_name, target)


static func get_trigger_state(soul_name : String, target : String = "player") -> Array:
	return DEBUG.get_trigger_state(soul_name, target)


static func clear_debug_events() -> void:
	DEBUG.clear_debug_events()


static func export_debug_log(path : String = "user://debug/test.jsonl") -> String:
	return DEBUG.export_debug_log(path)


static func set_debug_recording(enabled : bool) -> void:
	DEBUG.set_debug_recording(enabled)


static func watch_unit_for_debug(target : String = "player") -> bool:
	return DEBUG.watch_unit_for_debug(target)
