class_name BattleGrassSystem
extends RefCounted

const MAX_TRAMPLE_UNITS := 64
const BAKED_GRASS_PATH := "res://windows/Battle/assets/models/meadow_grass.res"

var grass_mat: ShaderMaterial
var _chars: Array[Vector4] = []


func setup(
	world: Node3D,
	height_fn: Callable,
	spacing: float = 0.135,
	blade_size: Vector2 = Vector2(0.48, 0.36),
	dirt_radius: float = 2.0
) -> void:
	var g_sh := load("res://windows/Battle/shaders/meadow_grass.gdshader") as Shader
	if g_sh == null:
		return

	_chars.resize(MAX_TRAMPLE_UNITS)
	for ci in range(MAX_TRAMPLE_UNITS):
		_chars[ci] = Vector4(0.0, -999.0, 0.0, 0.1)

	grass_mat = ShaderMaterial.new()
	grass_mat.shader = g_sh
	if ResourceLoader.exists("res://windows/Battle/assets/textures/grassleaf.png"):
		var gtex := load("res://windows/Battle/assets/textures/grassleaf.png")
		grass_mat.set_shader_parameter("albedo_texture", gtex)
		grass_mat.set_shader_parameter("accent_texture1", gtex)
	if ResourceLoader.exists("res://windows/Battle/assets/textures/accentleaf.png"):
		grass_mat.set_shader_parameter("accent_texture2", load("res://windows/Battle/assets/textures/accentleaf.png"))

	grass_mat.set_shader_parameter("albedo2_noise", _make_seamless_noise(101, 0.018, 128))
	grass_mat.set_shader_parameter("albedo3_noise", _make_seamless_noise(202, 0.015, 128))
	grass_mat.set_shader_parameter("wind_noise", _make_seamless_noise(303, 0.024, 128))

	var mm := _load_baked_multimesh(spacing, blade_size, dirt_radius)
	if mm == null:
		mm = _build_procedural_multimesh(height_fn, spacing, blade_size, dirt_radius)

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "ForestGrassCarpet"
	mmi.multimesh = mm
	mmi.material_override = grass_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16384.0
	world.add_child(mmi)


func _load_baked_multimesh(
	spacing: float,
	blade_size: Vector2,
	dirt_radius: float
) -> MultiMesh:
	if not ResourceLoader.exists(BAKED_GRASS_PATH):
		return null
	var mm := load(BAKED_GRASS_PATH) as MultiMesh
	if mm == null:
		return null
	var sp := float(mm.get_meta("grass_spacing", -1.0))
	var bs: Vector2 = mm.get_meta("blade_size", Vector2.ZERO)
	var dr := float(mm.get_meta("dirt_radius", -1.0))
	if not is_equal_approx(sp, spacing) or not bs.is_equal_approx(blade_size) or not is_equal_approx(dr, dirt_radius):
		return null
	return mm


func _build_procedural_multimesh(
	height_fn: Callable,
	spacing: float,
	blade_size: Vector2,
	dirt_radius: float
) -> MultiMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261126
	var half := 33.0
	var jitter := spacing * 0.48
	var inv_s2 := 0.70710678
	var buf := PackedFloat32Array()
	var cnt := 0
	var gx := -half
	while gx <= half:
		var gz := -half
		while gz <= half:
			var x := gx + rng.randf_range(-jitter, jitter)
			var z := gz + rng.randf_range(-jitter, jitter)
			var u := absf((x - z) * inv_s2)
			var v := absf((x + z) * inv_s2)
			if u <= 25.0 and v <= 23.5:
				var r := sqrt(x * x + z * z)
				var ang := atan2(z, x)
				var dr := dirt_radius + 0.45 * sin(ang * 2.0 + 0.7) + 0.30 * cos(ang * 3.0 - 0.9) + 0.18 * sin(ang * 5.0 + 1.4)
				var edge_f := clampf((r - (dr - 0.25)) / 1.15, 0.0, 1.0)
				if edge_f > 0.0 and (edge_f >= 1.0 or rng.randf() < edge_f * edge_f):
					var y: float = height_fn.call(x, z)
					var sc_x := rng.randf_range(0.85, 1.15) * lerpf(0.72, 1.0, edge_f)
					var sc_y := rng.randf_range(0.80, 1.15) * lerpf(0.65, 1.0, edge_f)
					var off := cnt * 12
					if buf.size() < off + 12:
						buf.resize(maxi(buf.size() * 2, 120000))
					buf[off] = sc_x
					buf[off + 1] = 0.0
					buf[off + 2] = 0.0
					buf[off + 3] = x
					buf[off + 4] = 0.0
					buf[off + 5] = sc_y
					buf[off + 6] = 0.0
					buf[off + 7] = y
					buf[off + 8] = 0.0
					buf[off + 9] = 0.0
					buf[off + 10] = 1.0
					buf[off + 11] = z
					cnt += 1
			gz += spacing
		gx += spacing

	buf.resize(cnt * 12)
	var qm := QuadMesh.new()
	qm.size = blade_size
	qm.center_offset = Vector3(0.0, blade_size.y * 0.36, 0.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = qm
	mm.instance_count = cnt
	if cnt > 0:
		mm.buffer = buf
	return mm


func set_trample_targets(targets: Array[Vector4]) -> void:
	if grass_mat == null:
		return
	var cnt := mini(targets.size(), MAX_TRAMPLE_UNITS)
	for i in range(cnt):
		_chars[i] = targets[i]
	grass_mat.set_shader_parameter("character_positions", _chars)
	grass_mat.set_shader_parameter("character_active_count", cnt)


func _make_seamless_noise(seed_val: int, freq: float, tex_sz: int = 128) -> NoiseTexture2D:
	var fn := FastNoiseLite.new()
	fn.seed = seed_val
	fn.frequency = freq
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var nt := NoiseTexture2D.new()
	nt.width = tex_sz
	nt.height = tex_sz
	nt.seamless = true
	nt.noise = fn
	return nt
