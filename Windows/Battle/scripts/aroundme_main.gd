class_name AroundMeMain
extends Control

const CAM_YAW := PI * 0.25
const CAM_ELEV := deg_to_rad(38.0)
const CAM_DIST := 78.0
const BASE_VIEW_H := 25.0
const MAX_IH := 620
const MAX_PIX := 690000.0
const MISSING_LAYER_FILL := Color(0.5, 0.5, 0.5, 1.0)

@export_group("Weather Presets")
## 可循环切换的天气预设列表（拖入 .tres 资源即可扩展新天气）
@export var weather_presets: Array[AroundMeWeatherPreset] = []
## 进入场景时默认启用的天气预设索引（从 0 开始）
@export var default_weather_index: int = 0

@export_group("Grass Carpet")
## 草丛之间的网格间距（米，越小草坪越密）
@export_range(0.08, 0.35, 0.005) var grass_spacing: float = 0.135
## 单簇草片的基础宽和高（米）
@export var grass_blade_size: Vector2 = Vector2(0.48, 0.36)
## 中心角色脚下自然泥土空地的基础半径（米）
@export_range(0.5, 5.0, 0.1) var dirt_clearing_radius: float = 2.0

@export_group("Depth of Field")
## 是否默认开启移轴景深虚化效果
@export var dof_enabled: bool = true
## 远景开始虚化的离焦距离（米，越大清晰区越深）
@export_range(1.0, 15.0, 0.2) var dof_far_start: float = 3.6
## 远景从开始虚化到最大模糊的过渡距离（米）
@export_range(4.0, 25.0, 0.5) var dof_far_range: float = 12.5
## 景深允许的最大模糊半径上限（像素）
@export_range(1.0, 10.0, 0.5) var dof_max_radius: float = 7.0

@onready var sub_vp: SubViewport = %SubViewport
@onready var world: Node3D = %World
@onready var world_env: WorldEnvironment = %WorldEnvironment
@onready var sun_light: DirectionalLight3D = $SubViewport/World/MorningSunLight
@onready var fill_light: DirectionalLight3D = $SubViewport/World/SkyFillLight
@onready var cam: Camera3D = %Camera3D
@onready var post_rect: TextureRect = %PostProcessRect
@onready var meadow_map: Node3D = %MeadowMap
@onready var game: AroundMeGame = %AroundMeGame
@onready var ui: AroundMeUI = %AroundMeUI

var post_mat: ShaderMaterial
var ao_mat: ShaderMaterial
var mist_mat: ShaderMaterial
var dof_mat: ShaderMaterial
var dof_mesh: MeshInstance3D
var mat_world: ShaderMaterial
var mat_unit: ShaderMaterial
var tex_albedo: Texture2DArray
var tex_height: Texture2DArray

var grass_sys := AroundMeGrassSystem.new()
var weather_ctrl := AroundMeWeatherController.new()

var cam_base: float = BASE_VIEW_H
var cam_aspect: float = 1.7778
var sub_texel := Vector2.ZERO
var dither_ofs := Vector2.ZERO
var screen_fade: float = 0.0
var paused: bool = false
var sim_speed: int = 1


func _ready() -> void:
	_init_shared_materials()
	_apply_world_material(meadow_map)
	_setup_viewport_and_post()
	grass_sys.setup(world, game, grass_spacing, grass_blade_size, dirt_clearing_radius)
	_init_weather_controller()
	game.init_game(mat_unit)
	ui.init_ui(self, game, cam, sub_vp)
	_on_window_resize()
	resized.connect(_on_window_resize)
	_sync_render_mode(is_visible_in_tree())
	print("[AroundMe] Morning Forest Clearing initialized.")


func _load_layer_img(path: String) -> Image:
	var res := load(path)
	var img: Image = null
	if res is Texture2D:
		img = (res as Texture2D).get_image()
	elif res is Image:
		img = res as Image
	if img == null:
		img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(MISSING_LAYER_FILL)
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if not img.has_mipmaps():
		img.generate_mipmaps()
	return img


func _init_shared_materials() -> void:
	var layer_names := [
		"00_dirt", "01_rock", "02_mason", "03_wood", "04_cobble",
		"05_metal", "06_slate", "07_cloth", "08_plain", "09_bark", "10_leaf",
	]
	var imgs_a: Array[Image] = []
	var imgs_h: Array[Image] = []
	for nm in layer_names:
		imgs_a.append(_load_layer_img("res://Windows/Battle/assets/textures/albedo_%s.png" % nm))
		imgs_h.append(_load_layer_img("res://Windows/Battle/assets/textures/height_%s.png" % nm))
	tex_albedo = Texture2DArray.new()
	tex_albedo.create_from_images(imgs_a)
	tex_height = Texture2DArray.new()
	tex_height.create_from_images(imgs_h)

	mat_world = ShaderMaterial.new()
	mat_world.shader = load("res://Windows/Battle/shaders/lit_world.gdshader")
	mat_world.set_shader_parameter("u_tex_a", tex_albedo)
	mat_world.set_shader_parameter("u_tex_h", tex_height)
	mat_world.set_shader_parameter("u_bump", 0.055)
	mat_world.set_shader_parameter("u_wind", 1.1)
	mat_world.set_shader_parameter("u_is_instanced", false)
	mat_world.set_shader_parameter("u_cover", Vector4(0.42, 0.66, 0.88, 0.60))
	mat_world.set_shader_parameter("u_cover_col", Vector3(0.24, 0.42, 0.16))
	mat_world.set_shader_parameter("u_cover_p", Vector4(0.92, 0.35, 0.35, 0.0))

	mat_unit = ShaderMaterial.new()
	mat_unit.shader = load("res://Windows/Battle/shaders/lit_unit.gdshader")
	mat_unit.set_shader_parameter("u_tex_a", tex_albedo)


func _apply_world_material(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.material_override == null:
			mi.material_override = mat_world
	for c in n.get_children():
		_apply_world_material(c)


func _setup_viewport_and_post() -> void:
	post_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	post_rect.texture = sub_vp.get_texture()
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://Windows/Battle/shaders/post_process.gdshader")
	post_rect.material = post_mat

	var mq := QuadMesh.new()
	mq.size = Vector2(2.0, 2.0)

	var ao_sh := load("res://Windows/Battle/shaders/atmo_ao.gdshader") as Shader
	if ao_sh != null:
		var ao_mesh := MeshInstance3D.new()
		ao_mesh.mesh = mq
		ao_mesh.extra_cull_margin = 16384.0
		ao_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ao_mat = ShaderMaterial.new()
		ao_mat.shader = ao_sh
		ao_mat.render_priority = 125
		ao_mesh.material_override = ao_mat
		cam.add_child(ao_mesh)

	var mist_sh := load("res://Windows/Battle/shaders/atmo_mist.gdshader") as Shader
	if mist_sh != null:
		var mist_mesh := MeshInstance3D.new()
		mist_mesh.mesh = mq
		mist_mesh.extra_cull_margin = 16384.0
		mist_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mist_mat = ShaderMaterial.new()
		mist_mat.shader = mist_sh
		mist_mat.render_priority = 126
		mist_mat.set_shader_parameter("u_light_count", 0)
		mist_mesh.material_override = mist_mat
		cam.add_child(mist_mesh)

	var dof_sh := load("res://Windows/Battle/shaders/atmo_dof.gdshader") as Shader
	if dof_sh != null:
		dof_mesh = MeshInstance3D.new()
		dof_mesh.mesh = mq
		dof_mesh.extra_cull_margin = 16384.0
		dof_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dof_mat = ShaderMaterial.new()
		dof_mat.shader = dof_sh
		dof_mat.render_priority = -20
		dof_mesh.material_override = dof_mat
		dof_mesh.visible = dof_enabled
		cam.add_child(dof_mesh)


func _init_weather_controller() -> void:
	var list: Array[AroundMeWeatherPreset] = weather_presets
	if list.is_empty():
		var sun_res := load("res://Windows/Battle/assets/weather/weather_sunny_morning.tres") as AroundMeWeatherPreset
		var rain_res := load("res://Windows/Battle/assets/weather/weather_storm_rain.tres") as AroundMeWeatherPreset
		if sun_res != null:
			list.append(sun_res)
		if rain_res != null:
			list.append(rain_res)
	weather_ctrl.init(
		world, list, default_weather_index, CAM_DIST,
		world_env, sun_light, fill_light,
		mist_mat, post_mat, mat_world, grass_sys.grass_mat
	)


func _on_window_resize() -> void:
	var win_sz := size
	var dw := maxf(win_sz.x, 2.0)
	var dh := maxf(win_sz.y, 2.0)
	var texel := maxf(2.0, maxf(sqrt(dw * dh / MAX_PIX), minf(dw, dh) / float(MAX_IH)))
	var ih := maxi(int(roundf(dh / texel)), mini(int(dh), 240))
	var iw := maxi(int(roundf(float(ih) * (dw / dh))), 320)
	if iw > 1500:
		ih = maxi(240, int(roundf(float(ih) * 1500.0 / float(iw))))
		iw = 1500
	sub_vp.size = Vector2i(iw, ih)
	post_mat.set_shader_parameter("u_tex_size", Vector2(iw, ih))
	post_mat.set_shader_parameter("u_out_size", Vector2(dw, dh))
	if ao_mat != null:
		ao_mat.set_shader_parameter("u_px", Vector2(1.0 / float(iw), 1.0 / float(ih)))
	if dof_mat != null:
		dof_mat.set_shader_parameter("u_px", Vector2(1.0 / float(iw), 1.0 / float(ih)))


func _process(delta: float) -> void:
	var active := is_visible_in_tree()
	_sync_render_mode(active)
	if not active:
		return

	var rdt := minf(delta, 0.05)

	if not paused:
		for _s in range(sim_speed):
			game.step_sim(rdt)

	grass_sys.update_trampling(game)
	_update_camera()

	screen_fade = minf(1.0, screen_fade + rdt * 1.45)
	post_mat.set_shader_parameter("u_sub", sub_texel)
	post_mat.set_shader_parameter("u_dither_ofs", dither_ofs)
	weather_ctrl.update(rdt, paused, screen_fade)

	if ao_mat != null:
		var px_w := cam.size / maxf(float(sub_vp.size.y), 1.0)
		var ao_rad := clampf(0.85 / maxf(px_w, 0.005), 8.0, 26.0)
		ao_mat.set_shader_parameter("u_ao", Vector3(1.0, ao_rad, 0.7))
		ao_mat.set_shader_parameter("u_dither", dither_ofs)
		ao_mat.set_shader_parameter("u_dof_fade", Vector4(CAM_DIST, dof_far_start, dof_far_range, 1.0 if dof_enabled else 0.0))

	if dof_mat != null and dof_enabled:
		var max_r := clampf(minf(float(sub_vp.size.y), float(sub_vp.size.x) * 1.6) * 0.012, 2.0, dof_max_radius)
		dof_mat.set_shader_parameter("u_dof", Vector4(CAM_DIST, dof_far_start, dof_far_range, max_r))
		dof_mat.set_shader_parameter("u_near", Vector4(9.0, 16.0, 0.6, 0.25))
		dof_mat.set_shader_parameter("u_dither", dither_ofs)

	ui.update_ui(rdt)
	ui.update_perf_overlay(
		rdt,
		int(Engine.get_frames_per_second()),
		game.mons.size(),
		game.kills,
		game.get_gpu_unit_count(),
		game.perf_sim_ms,
		game.perf_batch_ms,
		sub_vp.size
	)


func _sync_render_mode(active: bool) -> void:
	var mode: SubViewport.UpdateMode = SubViewport.UPDATE_DISABLED
	if active:
		mode = SubViewport.UPDATE_ALWAYS
	if sub_vp.render_target_update_mode != mode:
		sub_vp.render_target_update_mode = mode


func _update_camera() -> void:
	var win_sz := size
	cam_aspect = maxf(0.5, win_sz.x / maxf(win_sz.y, 1.0))
	cam_base = maxf(BASE_VIEW_H, 42.0 / cam_aspect)

	var sy := sin(CAM_YAW)
	var cy := cos(CAM_YAW)
	var c_dir := Vector3(cos(CAM_ELEV) * sy, sin(CAM_ELEV), cos(CAM_ELEV) * cy)
	var c_right := Vector3(cy, 0.0, -sy)
	var c_up := Vector3(-sin(CAM_ELEV) * sy, cos(CAM_ELEV), -sin(CAM_ELEV) * cy)

	var vh := cam_base
	var target := Vector3(0.0, 0.25, 0.0) + c_right * game.shake_offset.x + c_up * game.shake_offset.y
	var px := vh / maxf(float(sub_vp.size.y), 1.0)
	var u := target.dot(c_right)
	var v := target.dot(c_up)
	var su := roundf(u / px) * px
	var sv := roundf(v / px) * px
	sub_texel = Vector2((u - su) / px, (v - sv) / px)
	dither_ofs = Vector2(fposmod(roundf(su / px), 8.0), fposmod(roundf(sv / px), 8.0))
	target += c_right * (su - u) + c_up * (sv - v)
	cam.size = vh
	cam.look_at_from_position(target + c_dir * CAM_DIST, target, Vector3.UP)


func get_weather_label() -> String:
	return weather_ctrl.get_button_label()



func toggle_pause() -> void:
	paused = not paused
	game.play_ui_click()


func cycle_speed() -> void:
	sim_speed = (sim_speed % 3) + 1
	paused = false
	game.play_ui_click()


func toggle_mute() -> void:
	game.toggle_mute()


func toggle_dof() -> void:
	dof_enabled = not dof_enabled
	if dof_mesh != null:
		dof_mesh.visible = dof_enabled
	game.play_ui_click()


func toggle_weather() -> void:
	weather_ctrl.cycle_weather()
	game.play_ui_click()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_P or ke.keycode == KEY_SPACE:
			toggle_pause()
		elif ke.keycode == KEY_TAB:
			cycle_speed()
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_R:
			game.reset_run()
			game.play_ui_click()
		elif ke.keycode == KEY_K:
			game.spawn_stress_wave(100)
			game.play_ui_click()
			print("[AroundMe StressTest] Spawned +100 units | total_mons=%d | fps=%d" % [game.mons.size(), int(Engine.get_frames_per_second())])
		elif ke.keycode == KEY_L:
			ui.toggle_perf_overlay()
			game.play_ui_click()
		elif ke.keycode == KEY_M:
			toggle_mute()
