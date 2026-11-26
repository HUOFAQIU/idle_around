class_name AroundMeUI
extends Control

const HP_FRAME := Color(0.04, 0.04, 0.06, 0.88)
const SOLDIER_HP_BG := Color(0.16, 0.14, 0.12, 0.92)
const SOLDIER_HP_FILL := Color(0.32, 0.86, 0.96)
const SOLDIER_HP_LOW := Color(0.96, 0.34, 0.24)
const MOB_HP_FRAME := Color(0.04, 0.04, 0.06, 0.82)
const MOB_HP_FILL := Color(0.95, 0.42, 0.24)

var _main: AroundMeMain
var _game: AroundMeGame
var _cam: Camera3D
var _sub_vp: SubViewport

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
@onready var speed_btn: Button = %SpeedBtn
@onready var mute_btn: Button = %MuteBtn
@onready var dof_btn: Button = %DofBtn
@onready var weather_btn: Button = %WeatherBtn
@onready var perf_plate: PanelContainer = %PerfPlate
@onready var perf_line1: Label = %PerfLine1
@onready var perf_line2: Label = %PerfLine2
@onready var banner_lbl: Label = %BannerLabel


func init_ui(main_ref: AroundMeMain, game_ref: AroundMeGame, cam_ref: Camera3D, sub_vp_ref: SubViewport) -> void:
	_main = main_ref
	_game = game_ref
	_cam = cam_ref
	_sub_vp = sub_vp_ref

	var fnt := load("res://Windows/Battle/assets/fonts/pixel9.fnt")
	if fnt is FontFile:
		var ff := fnt as FontFile
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY

	_ic_pause = load("res://Windows/Battle/assets/icons/pause.png")
	_ic_play = load("res://Windows/Battle/assets/icons/play.png")
	_ic_sound = load("res://Windows/Battle/assets/icons/sound.png")
	_ic_mute = load("res://Windows/Battle/assets/icons/mute.png")

	overlay.draw.connect(_on_overlay_draw)
	pause_btn.pressed.connect(func(): _main.toggle_pause())
	speed_btn.pressed.connect(func(): _main.cycle_speed())
	mute_btn.pressed.connect(func(): _main.toggle_mute())
	dof_btn.pressed.connect(func(): _main.toggle_dof())
	weather_btn.pressed.connect(func(): _main.toggle_weather())
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

	wave_lbl.text = "W%d" % _game.wave
	kills_lbl.text = "%d" % _game.kills
	hp_lbl.text = "%d/%d" % [int(ceilf(_game.soldier_hp)), int(_game.soldier_max_hp)]
	mobs_lbl.text = "%d" % _game.mons.size()
	speed_btn.text = "%dx" % _main.sim_speed
	pause_btn.icon = _ic_play if _main.paused else _ic_pause
	mute_btn.icon = _ic_mute if _game.muted else _ic_sound
	dof_btn.text = "DOF:ON" if _main.dof_enabled else "DOF:OFF"
	weather_btn.text = _main.get_weather_label()

	if _game.soldier_dead:
		banner_lbl.visible = true
		banner_lbl.text = "SOLDIER FALLEN · RESPAWNING %.1fs" % maxf(0.0, _game.soldier_respawn_t)
	elif _main.paused:
		banner_lbl.visible = true
		banner_lbl.text = "PAUSED"
	else:
		banner_lbl.visible = false

	overlay.queue_redraw()


func _world_to_screen(p: Vector3) -> Vector2:
	var sp := _cam.unproject_position(p)
	var vp_sz := Vector2(_sub_vp.size)
	var win_sz := size
	if vp_sz.x < 1.0 or vp_sz.y < 1.0:
		return Vector2(-9999.0, -9999.0)
	return Vector2(sp.x / vp_sz.x * win_sz.x, sp.y / vp_sz.y * win_sz.y)


func _on_overlay_draw() -> void:
	if _game == null or _cam == null:
		return
	var s := float(ui_s)

	if not _game.soldier_dead:
		var sp := _world_to_screen(_game.soldier_pos + Vector3(0.0, 2.05, 0.0))
		var bw := 16.0 * s
		var bh := 2.0 * s
		var bx := roundf(sp.x - bw * 0.5)
		var by := roundf(sp.y - bh * 0.5)
		var frac := clampf(_game.soldier_hp / maxf(_game.soldier_max_hp, 1.0), 0.0, 1.0)
		overlay.draw_rect(Rect2(bx - s, by - s, bw + 2.0 * s, bh + 2.0 * s), HP_FRAME)
		overlay.draw_rect(Rect2(bx, by, bw, bh), SOLDIER_HP_BG)
		var col := SOLDIER_HP_FILL if frac > 0.35 else SOLDIER_HP_LOW
		overlay.draw_rect(Rect2(bx, by, bw * frac, bh), col)

	var drawn := 0
	for m in _game.mons:
		var hp := m.hp
		var mhp := m.max_hp
		if hp >= mhp - 0.01:
			continue
		var mp := m.pos + Vector3(0.0, m.archetype.hit_height + 0.45, 0.0)
		var sp := _world_to_screen(mp)
		var bw := 11.0 * s
		var bh := 1.5 * s
		var bx := roundf(sp.x - bw * 0.5)
		var by := roundf(sp.y)
		var frac := clampf(hp / maxf(mhp, 1.0), 0.0, 1.0)
		overlay.draw_rect(Rect2(bx - s * 0.5, by - s * 0.5, bw + s, bh + s), MOB_HP_FRAME)
		overlay.draw_rect(Rect2(bx, by, bw * frac, bh), MOB_HP_FILL)
		drawn += 1
		if drawn >= 48:
			break
