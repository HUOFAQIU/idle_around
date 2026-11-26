class_name BattleView3D
extends Control

const CAM_YAW := PI * 0.25
const CAM_ELEV := deg_to_rad(38.0)
const CAM_DIST := 78.0
const BASE_VIEW_H := 25.0
const MAX_IH := 620
const MAX_PIX := 690000.0
const MISSING_LAYER_FILL := Color(0.5, 0.5, 0.5, 1.0)

@export_group("Weather Presets")
## 可循环切换的天气预设列表（拖入 WeatherPreset .tres 资源即可扩展）
@export var weather_presets: Array[WeatherPreset] = []
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

var _post_mat: ShaderMaterial
var _ao_mat: ShaderMaterial
var _mist_mat: ShaderMaterial
var _dof_mat: ShaderMaterial
var _dof_mesh: MeshInstance3D
var _mat_world: ShaderMaterial
var _mat_unit: ShaderMaterial
var _tex_albedo: Texture2DArray
var _tex_height: Texture2DArray

var _grass_sys := BattleGrassSystem.new()
var _weather_ctrl := BattleWeatherController.new()

var _cam_base: float = BASE_VIEW_H
var _cam_aspect: float = 1.7778
var _sub_texel := Vector2.ZERO
var _dither_ofs := Vector2.ZERO
var _screen_fade: float = 0.0
var _shake_offset := Vector2.ZERO
var _initialized: bool = false


func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	_init_shared_materials()
	_apply_world_material(meadow_map)
	_setup_viewport_and_post()
	_grass_sys.setup(world, height_at, grass_spacing, grass_blade_size, dirt_clearing_radius)
	_init_weather_controller()
	_on_view_resized()
	resized.connect(_on_view_resized)
	sync_active(is_visible_in_tree())


func sync_active(active: bool) -> void:
	if sub_vp == null:
		return
	var mode := SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if sub_vp.render_target_update_mode != mode:
		sub_vp.render_target_update_mode = mode


func step_visuals(rdt: float, paused: bool) -> void:
	_update_camera()
	_screen_fade = minf(1.0, _screen_fade + rdt * 1.45)
	_post_mat.set_shader_parameter("u_sub", _sub_texel)
	_post_mat.set_shader_parameter("u_dither_ofs", _dither_ofs)
	_weather_ctrl.update(rdt, paused, _screen_fade)

	if _ao_mat != null:
		var px_w := cam.size / maxf(float(sub_vp.size.y), 1.0)
		var ao_rad := clampf(0.85 / maxf(px_w, 0.005), 8.0, 26.0)
		_ao_mat.set_shader_parameter("u_ao", Vector3(1.0, ao_rad, 0.7))
		_ao_mat.set_shader_parameter("u_dither", _dither_ofs)
		_ao_mat.set_shader_parameter("u_dof_fade", Vector4(CAM_DIST, dof_far_start, dof_far_range, 1.0 if dof_enabled else 0.0))

	if _dof_mat != null and dof_enabled:
		var max_r := clampf(minf(float(sub_vp.size.y), float(sub_vp.size.x) * 1.6) * 0.012, 2.0, dof_max_radius)
		_dof_mat.set_shader_parameter("u_dof", Vector4(CAM_DIST, dof_far_start, dof_far_range, max_r))
		_dof_mat.set_shader_parameter("u_near", Vector4(9.0, 16.0, 0.6, 0.25))
		_dof_mat.set_shader_parameter("u_dither", _dither_ofs)


func get_unit_material() -> ShaderMaterial:
	return _mat_unit


func get_world_root() -> Node3D:
	return world


func get_viewport_size() -> Vector2i:
	return sub_vp.size


func height_at(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var center_flat := clampf((r - 3.2) / 4.2, 0.0, 1.0)
	var roll := (sin(x * 0.16) * cos(z * 0.14) * 0.34 + sin((x + z) * 0.085) * 0.22) * center_flat
	var rim_rise := clampf((r - 17.0) / 14.0, 0.0, 1.0) * 0.55
	return 0.08 * (1.0 - center_flat) + roll + rim_rise


func set_trample_targets(targets: Array[Vector4]) -> void:
	_grass_sys.set_trample_targets(targets)


func set_camera_shake(offset: Vector2) -> void:
	_shake_offset = offset


func set_weather_preset(preset: WeatherPreset) -> void:
	_weather_ctrl.set_preset(preset)


func cycle_weather() -> void:
	_weather_ctrl.cycle_weather()


func get_weather_label() -> String:
	return _weather_ctrl.get_button_label()


func toggle_dof() -> void:
	dof_enabled = not dof_enabled
	if _dof_mesh != null:
		_dof_mesh.visible = dof_enabled


func world_to_screen(world_pos: Vector3) -> Vector2:
	var sp := cam.unproject_position(world_pos)
	var vp_sz := Vector2(sub_vp.size)
	if vp_sz.x < 1.0 or vp_sz.y < 1.0:
		return Vector2(-9999.0, -9999.0)
	return Vector2(sp.x / vp_sz.x * size.x, sp.y / vp_sz.y * size.y)


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
	_tex_albedo = Texture2DArray.new()
	_tex_albedo.create_from_images(imgs_a)
	_tex_height = Texture2DArray.new()
	_tex_height.create_from_images(imgs_h)

	_mat_world = ShaderMaterial.new()
	_mat_world.shader = load("res://Windows/Battle/shaders/lit_world.gdshader")
	_mat_world.set_shader_parameter("u_tex_a", _tex_albedo)
	_mat_world.set_shader_parameter("u_tex_h", _tex_height)
	_mat_world.set_shader_parameter("u_bump", 0.055)
	_mat_world.set_shader_parameter("u_wind", 1.1)
	_mat_world.set_shader_parameter("u_is_instanced", false)
	_mat_world.set_shader_parameter("u_cover", Vector4(0.42, 0.66, 0.88, 0.60))
	_mat_world.set_shader_parameter("u_cover_col", Vector3(0.24, 0.42, 0.16))
	_mat_world.set_shader_parameter("u_cover_p", Vector4(0.92, 0.35, 0.35, 0.0))

	_mat_unit = ShaderMaterial.new()
	_mat_unit.shader = load("res://Windows/Battle/shaders/lit_unit.gdshader")
	_mat_unit.set_shader_parameter("u_tex_a", _tex_albedo)


func _apply_world_material(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.material_override == null:
			mi.material_override = _mat_world
	for c in n.get_children():
		_apply_world_material(c)


func _setup_viewport_and_post() -> void:
	post_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	post_rect.texture = sub_vp.get_texture()
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = load("res://Windows/Battle/shaders/post_process.gdshader")
	post_rect.material = _post_mat

	var mq := QuadMesh.new()
	mq.size = Vector2(2.0, 2.0)

	var ao_sh := load("res://Windows/Battle/shaders/atmo_ao.gdshader") as Shader
	if ao_sh != null:
		var ao_mesh := MeshInstance3D.new()
		ao_mesh.mesh = mq
		ao_mesh.extra_cull_margin = 16384.0
		ao_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ao_mat = ShaderMaterial.new()
		_ao_mat.shader = ao_sh
		_ao_mat.render_priority = 125
		ao_mesh.material_override = _ao_mat
		cam.add_child(ao_mesh)

	var mist_sh := load("res://Windows/Battle/shaders/atmo_mist.gdshader") as Shader
	if mist_sh != null:
		var mist_mesh := MeshInstance3D.new()
		mist_mesh.mesh = mq
		mist_mesh.extra_cull_margin = 16384.0
		mist_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mist_mat = ShaderMaterial.new()
		_mist_mat.shader = mist_sh
		_mist_mat.render_priority = 126
		_mist_mat.set_shader_parameter("u_light_count", 0)
		mist_mesh.material_override = _mist_mat
		cam.add_child(mist_mesh)

	var dof_sh := load("res://Windows/Battle/shaders/atmo_dof.gdshader") as Shader
	if dof_sh != null:
		_dof_mesh = MeshInstance3D.new()
		_dof_mesh.mesh = mq
		_dof_mesh.extra_cull_margin = 16384.0
		_dof_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_dof_mat = ShaderMaterial.new()
		_dof_mat.shader = dof_sh
		_dof_mat.render_priority = -20
		_dof_mesh.material_override = _dof_mat
		_dof_mesh.visible = dof_enabled
		cam.add_child(_dof_mesh)


func _init_weather_controller() -> void:
	var list: Array[WeatherPreset] = weather_presets
	if list.is_empty():
		var sun_res := load("res://Windows/Battle/assets/weather/weather_sunny_morning.tres") as WeatherPreset
		var rain_res := load("res://Windows/Battle/assets/weather/weather_storm_rain.tres") as WeatherPreset
		if sun_res != null:
			list.append(sun_res)
		if rain_res != null:
			list.append(rain_res)
	_weather_ctrl.init(
		world, list, default_weather_index, CAM_DIST,
		world_env, sun_light, fill_light,
		_mist_mat, _post_mat, _mat_world, _grass_sys.grass_mat
	)


func _on_view_resized() -> void:
	var dw := maxf(size.x, 2.0)
	var dh := maxf(size.y, 2.0)
	var texel := maxf(2.0, maxf(sqrt(dw * dh / MAX_PIX), minf(dw, dh) / float(MAX_IH)))
	var ih := maxi(int(roundf(dh / texel)), mini(int(dh), 240))
	var iw := maxi(int(roundf(float(ih) * (dw / dh))), 320)
	if iw > 1500:
		ih = maxi(240, int(roundf(float(ih) * 1500.0 / float(iw))))
		iw = 1500
	sub_vp.size = Vector2i(iw, ih)
	_post_mat.set_shader_parameter("u_tex_size", Vector2(iw, ih))
	_post_mat.set_shader_parameter("u_out_size", Vector2(dw, dh))
	if _ao_mat != null:
		_ao_mat.set_shader_parameter("u_px", Vector2(1.0 / float(iw), 1.0 / float(ih)))
	if _dof_mat != null:
		_dof_mat.set_shader_parameter("u_px", Vector2(1.0 / float(iw), 1.0 / float(ih)))


func _update_camera() -> void:
	_cam_aspect = maxf(0.5, size.x / maxf(size.y, 1.0))
	_cam_base = maxf(BASE_VIEW_H, 42.0 / _cam_aspect)

	var sy := sin(CAM_YAW)
	var cy := cos(CAM_YAW)
	var c_dir := Vector3(cos(CAM_ELEV) * sy, sin(CAM_ELEV), cos(CAM_ELEV) * cy)
	var c_right := Vector3(cy, 0.0, -sy)
	var c_up := Vector3(-sin(CAM_ELEV) * sy, cos(CAM_ELEV), -sin(CAM_ELEV) * cy)

	var vh := _cam_base
	var target := Vector3(0.0, 0.25, 0.0) + c_right * _shake_offset.x + c_up * _shake_offset.y
	var px := vh / maxf(float(sub_vp.size.y), 1.0)
	var u := target.dot(c_right)
	var v := target.dot(c_up)
	var su := roundf(u / px) * px
	var sv := roundf(v / px) * px
	_sub_texel = Vector2((u - su) / px, (v - sv) / px)
	_dither_ofs = Vector2(fposmod(roundf(su / px), 8.0), fposmod(roundf(sv / px), 8.0))
	target += c_right * (su - u) + c_up * (sv - v)
	cam.size = vh
	cam.look_at_from_position(target + c_dir * CAM_DIST, target, Vector3.UP)
