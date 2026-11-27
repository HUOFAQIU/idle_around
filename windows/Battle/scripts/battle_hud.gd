class_name BattleHud
extends Control

const HP_FRAME := Color(0.04, 0.04, 0.06, 0.88)
const SOLDIER_HP_BG := Color(0.16, 0.14, 0.12, 0.92)
const SOLDIER_HP_FILL := Color(0.32, 0.86, 0.96)
const SOLDIER_HP_LOW := Color(0.96, 0.34, 0.24)
const MOB_HP_FRAME := Color(0.04, 0.04, 0.06, 0.82)
const MOB_HP_FILL := Color(0.95, 0.42, 0.24)

var _main: BattleArena
var _game: BattleSim
var _view_3d: BattleView3D

var ui_s: int = 3
var show_perf: bool = false
var _perf_acc_t: float = 0.25
var _perf_sim_avg: float = 0.0
var _perf_batch_avg: float = 0.0

var _ic_pause: Texture2D
var _ic_play: Texture2D
var _ic_sound: Texture2D
var _ic_mute: Texture2D

@onready var overlay: Control = %WorldOverlay
@onready var hud_root: Control = %HudRoot
@onready var wave_lbl: Label = %WaveLabel
@onready var kills_lbl: Label = %KillsLabel
@onready var hp_lbl: Label = %HpLabel
@onready var mobs_lbl: Label = %MobsLabel
@onready var pause_btn: Button = %PauseBtn
@onready var mute_btn: Button = %MuteBtn
@onready var dof_btn: Button = %DofBtn
@onready var weather_btn: Button = %WeatherBtn
@onready var stress_btn: Button = %StressBtn
@onready var perf_btn: Button = %PerfBtn
@onready var reset_btn: Button = %ResetBtn
@onready var perf_plate: PanelContainer = %PerfPlate
@onready var perf_line1: Label = %PerfLine1
@onready var perf_line2: Label = %PerfLine2
@onready var banner_lbl: Label = %BannerLabel


func init_ui(main_ref: BattleArena, game_ref: BattleSim, view_ref: BattleView3D) -> void:
	_main = main_ref
	_game = game_ref
	_view_3d = view_ref

	var fnt := load("res://windows/Battle/assets/fonts/pixel9.fnt")
	if fnt is FontFile:
		var ff := fnt as FontFile
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY

	_ic_pause = load("res://windows/Battle/assets/icons/pause.png")
	_ic_play = load("res://windows/Battle/assets/icons/play.png")
	_ic_sound = load("res://windows/Battle/assets/icons/sound.png")
	_ic_mute = load("res://windows/Battle/assets/icons/mute.png")

	overlay.draw.connect(_on_overlay_draw)
	pause_btn.pressed.connect(func(): _main.toggle_pause())
	mute_btn.pressed.connect(func(): _main.toggle_mute())
	dof_btn.pressed.connect(func(): _main.toggle_dof())
	weather_btn.pressed.connect(func(): _main.toggle_weather())
	stress_btn.pressed.connect(func(): _main.spawn_stress_wave())
	perf_btn.pressed.connect(func(): _main.toggle_perf_overlay())
	reset_btn.pressed.connect(func(): _main.reset_run())
	perf_plate.visible = false
	banner_lbl.visible = false


func toggle_perf_overlay() -> void:
	show_perf = not show_perf
	perf_plate.visible = show_perf
	_perf_acc_t = 0.25


func update_perf_overlay(dt: float, fps: int, mons_n: int, kills_n: int, gpu_units: int, sim_ms: float, batch_ms: float, vp_sz: Vector2i) -> void:
	if not show_perf:
		return
	_perf_sim_avg = lerpf(_perf_sim_avg, sim_ms, 0.25)
	_perf_batch_avg = lerpf(_perf_batch_avg, batch_ms, 0.25)
	_perf_acc_t += dt
	if _perf_acc_t < 0.22:
		return
	_perf_acc_t = 0.0
	perf_line1.text = "FPS %d · Mons %d · Kills %d · Units %d" % [fps, mons_n, kills_n, gpu_units]
	perf_line2.text = "CPU Sim %.1fms · Batch %.1fms · VP %dx%d" % [_perf_sim_avg, _perf_batch_avg, vp_sz.x, vp_sz.y]


func update_ui(_dt: float) -> void:
	var win_sz := size
	ui_s = maxi(2, int(roundf(win_sz.y / 430.0)))
	var lw := win_sz.x / float(ui_s)
	var lh := win_sz.y / float(ui_s)
	hud_root.scale = Vector2(ui_s, ui_s)
	hud_root.size = Vector2(lw, lh)

	wave_lbl.text = _game.get_progress_label()
	kills_lbl.text = "%d" % _game.kills
	hp_lbl.text = "%d/%d" % [int(ceilf(_game.soldier_hp)), int(_game.soldier_max_hp)]
	mobs_lbl.text = "%d" % _game.get_enemy_count()
	pause_btn.icon = _ic_play if _main.paused else _ic_pause
	mute_btn.icon = _ic_mute if _game.muted else _ic_sound
	dof_btn.text = "DOF:ON" if _main.is_dof_enabled() else "DOF:OFF"
	weather_btn.text = _main.get_weather_label()
	perf_btn.text = "PERF*" if show_perf else "PERF"

	if _game.soldier_dead:
		banner_lbl.visible = true
		banner_lbl.text = "SOLDIER FALLEN · RESPAWNING %.1fs" % maxf(0.0, _game.soldier_respawn_t)
	elif _game.map_clear_restart_t > 0.0:
		banner_lbl.visible = true
		banner_lbl.text = "MAP CLEARED · RESTARTING %.1fs" % maxf(0.0, _game.map_clear_restart_t)
	elif _main.paused:
		banner_lbl.visible = true
		banner_lbl.text = "PAUSED"
	else:
		banner_lbl.visible = false

	overlay.queue_redraw()


func _on_overlay_draw() -> void:
	if _game == null or _view_3d == null:
		return
	var s := float(ui_s)

	if not _game.soldier_dead:
		var sp := _view_3d.world_to_screen(_game.soldier_pos + Vector3(0.0, 2.05, 0.0))
		var bw := 16.0 * s
		var bh := 2.0 * s
		var bx := roundf(sp.x - bw * 0.5)
		var by := roundf(sp.y - bh * 0.5)
		var frac := clampf(_game.soldier_hp / maxf(_game.soldier_max_hp, 1.0), 0.0, 1.0)
		overlay.draw_rect(Rect2(bx - s, by - s, bw + 2.0 * s, bh + 2.0 * s), HP_FRAME)
		overlay.draw_rect(Rect2(bx, by, bw, bh), SOLDIER_HP_BG)
		var col := SOLDIER_HP_FILL if frac > 0.35 else SOLDIER_HP_LOW
		overlay.draw_rect(Rect2(bx, by, bw * frac, bh), col)

	for m in _game.get_hp_bar_entries():
		var hp: float = m["hp"]
		var mhp: float = m["max_hp"]
		if hp >= mhp - 0.01:
			continue
		var mp: Vector3 = m["pos"]
		var sp := _view_3d.world_to_screen(mp)
		var bw := 11.0 * s
		var bh := 1.5 * s
		var bx := roundf(sp.x - bw * 0.5)
		var by := roundf(sp.y)
		var frac := clampf(hp / maxf(mhp, 1.0), 0.0, 1.0)
		overlay.draw_rect(Rect2(bx - s * 0.5, by - s * 0.5, bw + s, bh + s), MOB_HP_FRAME)
		overlay.draw_rect(Rect2(bx, by, bw * frac, bh), MOB_HP_FILL)
