class_name BattleArena
extends Control

signal battle_logged(line: String)

@onready var view_3d: BattleView3D = %BattleView3D
@onready var game: BattleSim = %BattleSim
@onready var ui: BattleHud = %BattleHud

var paused: bool = false


func _ready() -> void:
	view_3d.initialize()
	game.battle_logged.connect(func(line: String) -> void: battle_logged.emit(line))
	game.init_game(view_3d.get_unit_material(), view_3d.height_at)
	ui.init_ui(self, game, view_3d)
	print("[BattleArena] Morning Forest Clearing initialized.")


func _process(delta: float) -> void:
	var active := is_visible_in_tree()
	view_3d.sync_active(active)
	if not active:
		return

	var rdt := minf(delta, 0.05)
	if not paused:
		game.step_sim(rdt)

	view_3d.set_trample_targets(game.collect_trample_targets())
	view_3d.set_camera_shake(game.shake_offset)
	view_3d.step_visuals(rdt, paused)

	ui.update_ui(rdt)
	ui.update_perf_overlay(
		rdt,
		int(Engine.get_frames_per_second()),
		game.mons.size(),
		game.kills,
		game.get_gpu_unit_count(),
		game.perf_sim_ms,
		game.perf_batch_ms,
		view_3d.get_viewport_size()
	)


func get_weather_label() -> String:
	return view_3d.get_weather_label()


func is_dof_enabled() -> bool:
	return view_3d.dof_enabled


func toggle_pause() -> void:
	paused = not paused
	game.play_ui_click()


func toggle_mute() -> void:
	game.toggle_mute()


func toggle_dof() -> void:
	view_3d.toggle_dof()
	game.play_ui_click()


func toggle_weather() -> void:
	view_3d.cycle_weather()
	game.play_ui_click()


func spawn_stress_wave() -> void:
	game.spawn_stress_wave(100)
	game.play_ui_click()


func toggle_perf_overlay() -> void:
	ui.toggle_perf_overlay()
	game.play_ui_click()


func start_run() -> void:
	paused = false
	game.reset_run()


func set_weather_preset(preset: WeatherPreset) -> void:
	view_3d.set_weather_preset(preset)


func reset_run() -> void:
	game.reset_run()
	game.play_ui_click()
