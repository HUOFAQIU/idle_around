class_name BattleWeatherController
extends RefCounted

const MAX_PARTICLES := 650

var presets: Array[WeatherPreset] = []
var active_index: int = 0
var lightning_enabled: bool = true

var _wx_mat: ShaderMaterial
var _mist_mat: ShaderMaterial
var _post_mat: ShaderMaterial
var _mat_world: ShaderMaterial
var _grass_mat: ShaderMaterial
var _world_env: WorldEnvironment
var _sun_light: DirectionalLight3D
var _fill_light: DirectionalLight3D
var _focus_dist: float = 78.0

var _lightning_timer: float = 6.5
var _lightning_flash: float = 0.0


func init(
	world: Node3D,
	preset_list: Array[WeatherPreset],
	start_index: int,
	focus_dist: float,
	world_env: WorldEnvironment,
	sun_light: DirectionalLight3D,
	fill_light: DirectionalLight3D,
	mist_mat: ShaderMaterial,
	post_mat: ShaderMaterial,
	mat_world: ShaderMaterial,
	grass_mat: ShaderMaterial
) -> void:
	_focus_dist = focus_dist
	_world_env = world_env
	_sun_light = sun_light
	_fill_light = fill_light
	_mist_mat = mist_mat
	_post_mat = post_mat
	_mat_world = mat_world
	_grass_mat = grass_mat

	presets.clear()
	for p in preset_list:
		if p != null:
			presets.append(p)
	if presets.is_empty():
		presets.append(WeatherPreset.new())

	active_index = clampi(start_index, 0, presets.size() - 1)
	_setup_particle_multimesh(world)
	apply_active_preset()


func get_active_preset() -> WeatherPreset:
	return presets[active_index]


func get_button_label() -> String:
	return get_active_preset().button_label


func set_preset(preset: WeatherPreset) -> void:
	if preset == null:
		return
	var idx := presets.find(preset)
	if idx < 0:
		presets.append(preset)
		idx = presets.size() - 1
	active_index = idx
	_lightning_flash = 0.0
	_lightning_timer = randf_range(1.5, minf(4.5, preset.lightning_interval_min))
	apply_active_preset()


func cycle_weather() -> void:
	active_index = (active_index + 1) % presets.size()
	var p := get_active_preset()
	_lightning_flash = 0.0
	_lightning_timer = randf_range(1.5, minf(4.5, p.lightning_interval_min))
	apply_active_preset()


func apply_active_preset() -> void:
	var p := get_active_preset()

	if _world_env != null and _world_env.environment != null:
		_world_env.environment.background_color = p.background_color
		_world_env.environment.ambient_light_color = p.ambient_color
		_world_env.environment.ambient_light_energy = p.ambient_energy

	if _mist_mat != null:
		_mist_mat.set_shader_parameter("u_mist_amb", Vector3(p.mist_color.r, p.mist_color.g, p.mist_color.b))
		_mist_mat.set_shader_parameter("u_mist", Vector4(p.mist_base_y, p.mist_scale_h, p.mist_density, p.mist_gain))

	if _mat_world != null:
		_mat_world.set_shader_parameter("u_wet", p.ground_wetness)
	if _grass_mat != null:
		_grass_mat.set_shader_parameter("u_rain", p.grass_rain_amount)

	if _wx_mat != null:
		_wx_mat.set_shader_parameter("u_amb", Vector3(p.particle_ambient.r, p.particle_ambient.g, p.particle_ambient.b))
		_wx_mat.set_shader_parameter("u_n", Vector2(p.particle_a_ratio, p.particle_b_ratio))
		_wx_mat.set_shader_parameter("u_vel_a", p.particle_a_vel)
		_wx_mat.set_shader_parameter("u_vel_b", p.particle_b_vel)
		_wx_mat.set_shader_parameter("u_sway_a", p.particle_a_sway)
		_wx_mat.set_shader_parameter("u_sway_b", p.particle_b_sway)
		_wx_mat.set_shader_parameter("u_size_a", p.particle_a_size)
		_wx_mat.set_shader_parameter("u_size_b", p.particle_b_size)
		_wx_mat.set_shader_parameter("u_col_a", Vector4(p.particle_a_color.r, p.particle_a_color.g, p.particle_a_color.b, p.particle_a_color.a))
		_wx_mat.set_shader_parameter("u_col_b", Vector4(p.particle_b_color.r, p.particle_b_color.g, p.particle_b_color.b, p.particle_b_color.a))
		_wx_mat.set_shader_parameter("u_al_a", Vector3(p.particle_a_alpha, p.particle_a_twinkle, p.particle_a_stretch))
		_wx_mat.set_shader_parameter("u_al_b", Vector3(p.particle_b_alpha, p.particle_b_twinkle, p.particle_b_stretch))
		_wx_mat.set_shader_parameter("u_ya", p.particle_a_y_range)
		_wx_mat.set_shader_parameter("u_yb", p.particle_b_y_range)


func update(rdt: float, paused: bool, screen_fade: float) -> void:
	var p := get_active_preset()
	if p.allow_lightning and lightning_enabled and not paused:
		_lightning_timer -= rdt
		if _lightning_timer <= 0.0:
			_lightning_flash = 1.0
			_lightning_timer = randf_range(p.lightning_interval_min, p.lightning_interval_max)
	_lightning_flash = maxf(0.0, _lightning_flash - rdt * 3.8)

	var bolt := 0.0
	if p.allow_lightning and lightning_enabled and _lightning_flash > 0.01:
		var dbl := 1.0 if (_lightning_flash > 0.65 or (_lightning_flash > 0.22 and _lightning_flash < 0.45)) else 0.25
		bolt = _lightning_flash * dbl

	if _sun_light != null:
		_sun_light.light_color = p.sun_color.lerp(p.lightning_sun_color, bolt)
		_sun_light.light_energy = p.sun_energy + bolt * p.lightning_sun_boost
	if _fill_light != null:
		_fill_light.light_color = p.fill_color.lerp(p.lightning_sun_color, bolt * 0.85)
		_fill_light.light_energy = p.fill_energy + bolt * p.lightning_fill_boost
	if _world_env != null and _world_env.environment != null:
		_world_env.environment.ambient_light_energy = p.ambient_energy + bolt * p.lightning_ambient_boost

	if _post_mat != null:
		_post_mat.set_shader_parameter("u_grade", Vector4(p.exposure + bolt * p.lightning_exposure_boost, p.saturation, p.vignette, screen_fade))
		_post_mat.set_shader_parameter("u_lift", p.shadow_lift)


func _setup_particle_multimesh(world: Node3D) -> void:
	var wx_sh := load("res://windows/Battle/shaders/weather.gdshader") as Shader
	if wx_sh == null:
		return
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = qm
	mm.instance_count = MAX_PARTICLES
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for wi in range(MAX_PARTICLES):
		mm.set_instance_transform(wi, Transform3D.IDENTITY)
		mm.set_instance_custom_data(wi, Color(rng.randf(), rng.randf(), rng.randf(), (float(wi) + 0.5) / float(MAX_PARTICLES)))

	_wx_mat = ShaderMaterial.new()
	_wx_mat.shader = wx_sh
	_wx_mat.set_shader_parameter("u_light_count", 0)
	_wx_mat.set_shader_parameter("u_focus_dist", _focus_dist)

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "WeatherParticles"
	mmi.multimesh = mm
	mmi.material_override = _wx_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16384.0
	world.add_child(mmi)
