class_name BattleFxPool
extends RefCounted

const MAX_DEBRIS := 260
const MAX_SPARKS := 260
const MAX_SLASHES := 32
const MAX_RINGS := 48
const MAX_PROJECTILES := 96
const SLASH_DURATION := 0.24
const CLAW_SLASH_SHADER: Shader = preload("res://windows/Battle/shaders/claw_slash_3d.gdshader")
const RING_SHADER: Shader = preload("res://windows/Battle/shaders/fx_ring_3d.gdshader")

var _debris_mm: MultiMesh
var _debris_buf := PackedFloat32Array()
var _debris: Array[Dictionary] = []

var _sparks_mm: MultiMesh
var _sparks_buf := PackedFloat32Array()
var _sparks: Array[Dictionary] = []

var _slashes_mm: MultiMesh
var _slashes_buf := PackedFloat32Array()
var _slashes: Array[Dictionary] = []

var _rings_mm: MultiMesh
var _rings_buf := PackedFloat32Array()
var _rings: Array[Dictionary] = []

var _proj_mm: MultiMesh
var _proj_buf := PackedFloat32Array()


func init(owner: Node3D) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_debris_mm = MultiMesh.new()
	_debris_mm.transform_format = MultiMesh.TRANSFORM_3D
	_debris_mm.use_colors = true
	_debris_mm.mesh = box
	_debris_mm.instance_count = MAX_DEBRIS
	_debris_mm.visible_instance_count = 0
	_debris_buf.resize(MAX_DEBRIS * 16)
	var dmmi := MultiMeshInstance3D.new()
	dmmi.multimesh = _debris_mm
	var dmat := StandardMaterial3D.new()
	dmat.vertex_color_use_as_albedo = true
	dmat.roughness = 0.85
	dmmi.material_override = dmat
	dmmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dmmi.extra_cull_margin = 16384.0
	owner.add_child(dmmi)

	var sq := QuadMesh.new()
	sq.size = Vector2(0.18, 0.18)
	_sparks_mm = MultiMesh.new()
	_sparks_mm.transform_format = MultiMesh.TRANSFORM_3D
	_sparks_mm.use_colors = true
	_sparks_mm.mesh = sq
	_sparks_mm.instance_count = MAX_SPARKS
	_sparks_mm.visible_instance_count = 0
	_sparks_buf.resize(MAX_SPARKS * 16)
	var smmi := MultiMeshInstance3D.new()
	smmi.multimesh = _sparks_mm
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	smat.vertex_color_use_as_albedo = true
	smat.no_depth_test = false
	if ResourceLoader.exists("res://windows/Battle/assets/textures/particle_soft.png"):
		smat.albedo_texture = load("res://windows/Battle/assets/textures/particle_soft.png")
	smmi.material_override = smat
	smmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smmi.extra_cull_margin = 16384.0
	owner.add_child(smmi)

	var slash_q := QuadMesh.new()
	slash_q.size = Vector2.ONE
	_slashes_mm = MultiMesh.new()
	_slashes_mm.transform_format = MultiMesh.TRANSFORM_3D
	_slashes_mm.use_custom_data = true
	_slashes_mm.mesh = slash_q
	_slashes_mm.instance_count = MAX_SLASHES
	_slashes_mm.visible_instance_count = 0
	_slashes_buf.resize(MAX_SLASHES * 16)
	var clmmi := MultiMeshInstance3D.new()
	clmmi.multimesh = _slashes_mm
	var clmat := ShaderMaterial.new()
	clmat.shader = CLAW_SLASH_SHADER
	clmmi.material_override = clmat
	clmmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clmmi.extra_cull_margin = 16384.0
	owner.add_child(clmmi)

	var ring_m := PlaneMesh.new()
	ring_m.size = Vector2(2.0, 2.0)
	_rings_mm = MultiMesh.new()
	_rings_mm.transform_format = MultiMesh.TRANSFORM_3D
	_rings_mm.use_colors = true
	_rings_mm.use_custom_data = true
	_rings_mm.mesh = ring_m
	_rings_mm.instance_count = MAX_RINGS
	_rings_mm.visible_instance_count = 0
	_rings_buf.resize(MAX_RINGS * 20)
	var rmmi := MultiMeshInstance3D.new()
	rmmi.multimesh = _rings_mm
	var rmat := ShaderMaterial.new()
	rmat.shader = RING_SHADER
	rmmi.material_override = rmat
	rmmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rmmi.extra_cull_margin = 16384.0
	owner.add_child(rmmi)

	var proj_box := BoxMesh.new()
	proj_box.size = Vector3(0.09, 0.09, 0.72)
	_proj_mm = MultiMesh.new()
	_proj_mm.transform_format = MultiMesh.TRANSFORM_3D
	_proj_mm.use_colors = true
	_proj_mm.mesh = proj_box
	_proj_mm.instance_count = MAX_PROJECTILES
	_proj_mm.visible_instance_count = 0
	_proj_buf.resize(MAX_PROJECTILES * 16)
	var pmmi := MultiMeshInstance3D.new()
	pmmi.multimesh = _proj_mm
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.vertex_color_use_as_albedo = true
	pmmi.material_override = pmat
	pmmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pmmi.extra_cull_margin = 16384.0
	owner.add_child(pmmi)


func clear() -> void:
	_debris.clear()
	_sparks.clear()
	_slashes.clear()
	_rings.clear()
	if _debris_mm != null:
		_debris_mm.visible_instance_count = 0
	if _sparks_mm != null:
		_sparks_mm.visible_instance_count = 0
	if _slashes_mm != null:
		_slashes_mm.visible_instance_count = 0
	if _rings_mm != null:
		_rings_mm.visible_instance_count = 0
	if _proj_mm != null:
		_proj_mm.visible_instance_count = 0


func spawn_sparks(pos: Vector3, count: int, col: Color, spd: float = 3.8) -> void:
	for _i in range(count):
		if _sparks.size() >= MAX_SPARKS:
			break
		var d := Vector3(randf_range(-1, 1), randf_range(0.35, 1.3), randf_range(-1, 1)).normalized()
		_sparks.append({
			"p": pos,
			"v": d * randf_range(spd * 0.45, spd),
			"col": col,
			"t": 0.0,
			"dur": randf_range(0.18, 0.38),
			"sz": randf_range(0.7, 1.4),
			"grav": 9.5,
		})


func spawn_status_particles(pos: Vector3, count: int, col: Color, rise_speed: float = 1.8) -> void:
	for _i in range(count):
		if _sparks.size() >= MAX_SPARKS:
			break
		var ofs := Vector3(randf_range(-0.32, 0.32), randf_range(0.05, 0.35), randf_range(-0.32, 0.32))
		var vel := Vector3(randf_range(-0.55, 0.55), randf_range(rise_speed * 0.65, rise_speed), randf_range(-0.55, 0.55))
		_sparks.append({
			"p": pos + ofs,
			"v": vel,
			"col": col,
			"t": 0.0,
			"dur": randf_range(0.32, 0.58),
			"sz": randf_range(0.8, 1.45),
			"grav": 1.2,
		})


func spawn_ring(
	pos: Vector3,
	col: Color,
	radius: float = 1.2,
	dur: float = 0.36,
	width: float = 0.16,
	rise_y: float = 0.0
) -> void:
	if _rings.size() >= MAX_RINGS:
		_rings.remove_at(0)
	_rings.append({
		"p": Vector3(pos.x, pos.y + 0.08, pos.z),
		"col": col,
		"rad": maxf(radius, 0.35),
		"t": 0.0,
		"dur": maxf(dur, 0.08),
		"w": width,
		"rise": rise_y,
	})


func sync_projectiles(nodes: Array, to_3d_fn: Callable) -> void:
	if _proj_mm == null:
		return
	var pc := 0
	for node in nodes:
		if pc >= MAX_PROJECTILES:
			break
		if not node is SoulProjectile:
			continue
		var proj := node as SoulProjectile
		if not proj.is_active():
			continue
		var pos3: Vector3 = to_3d_fn.call(proj.position)
		pos3.y += 0.65
		var dir2 := Vector2.from_angle(proj.rotation - PI * 0.5)
		var yaw := atan2(dir2.x, dir2.y)
		var cy := cos(yaw)
		var sy := sin(yaw)
		var off := pc * 16
		_proj_buf[off] = cy; _proj_buf[off + 1] = 0.0; _proj_buf[off + 2] = sy; _proj_buf[off + 3] = pos3.x
		_proj_buf[off + 4] = 0.0; _proj_buf[off + 5] = 1.0; _proj_buf[off + 6] = 0.0; _proj_buf[off + 7] = pos3.y
		_proj_buf[off + 8] = -sy; _proj_buf[off + 9] = 0.0; _proj_buf[off + 10] = cy; _proj_buf[off + 11] = pos3.z
		var col := proj.modulate
		_proj_buf[off + 12] = col.r * 1.8; _proj_buf[off + 13] = col.g * 1.8; _proj_buf[off + 14] = col.b * 1.8; _proj_buf[off + 15] = 1.0
		pc += 1
	_proj_mm.visible_instance_count = pc
	if pc > 0:
		_proj_mm.buffer = _proj_buf


func spawn_claw_slash(pos: Vector3, direction: float = 1.0, scale: float = 1.65) -> void:
	if _slashes.size() >= MAX_SLASHES:
		_slashes.remove_at(0)
	_slashes.append({
		"p": pos,
		"dir": -1.0 if direction < 0.0 else 1.0,
		"tilt": randf_range(-0.14, 0.14),
		"sc": scale,
		"t": 0.0,
		"dur": SLASH_DURATION,
	})


func spawn_shatter(pos: Vector3, sc: float, col: Color, dir: Vector3) -> void:
	var n := mini(5, MAX_DEBRIS - _debris.size())
	for _i in range(n):
		var v := dir + Vector3(randf_range(-2.2, 2.2), randf_range(1.8, 4.4), randf_range(-2.2, 2.2))
		_debris.append({
			"p": pos + Vector3(randf_range(-0.2, 0.2), randf_range(0.15, 0.7), randf_range(-0.2, 0.2)),
			"v": v,
			"r": Vector3(randf() * TAU, randf() * TAU, randf() * TAU),
			"rv": Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)),
			"sz": randf_range(0.10, 0.20) * sc,
			"col": col * randf_range(0.85, 1.15),
			"t": 0.0,
			"dur": randf_range(0.45, 0.85),
		})


func step(dt: float, height_fn: Callable) -> void:
	var dc := 0
	for i in range(_debris.size() - 1, -1, -1):
		var d := _debris[i]
		d["t"] = float(d["t"]) + dt
		if float(d["t"]) >= float(d["dur"]):
			_debris.remove_at(i)
			continue
		var v: Vector3 = d["v"]
		v.y -= 14.0 * dt
		var p: Vector3 = d["p"] + v * dt
		var gy: float = height_fn.call(p.x, p.z)
		if p.y < gy + 0.05:
			p.y = gy + 0.05
			v.y = absf(v.y) * 0.35
			v.x *= 0.72; v.z *= 0.72
		d["p"] = p; d["v"] = v
		var r: Vector3 = d["r"] + (d["rv"] as Vector3) * dt
		d["r"] = r
		var fade := 1.0 - float(d["t"]) / float(d["dur"])
		var s := float(d["sz"]) * clampf(fade * 1.6, 0.05, 1.0)
		var bas := Basis.from_euler(r).scaled(Vector3(s, s, s))
		var off := dc * 16
		_debris_buf[off] = bas.x.x; _debris_buf[off + 1] = bas.y.x; _debris_buf[off + 2] = bas.z.x; _debris_buf[off + 3] = p.x
		_debris_buf[off + 4] = bas.x.y; _debris_buf[off + 5] = bas.y.y; _debris_buf[off + 6] = bas.z.y; _debris_buf[off + 7] = p.y
		_debris_buf[off + 8] = bas.x.z; _debris_buf[off + 9] = bas.y.z; _debris_buf[off + 10] = bas.z.z; _debris_buf[off + 11] = p.z
		var col: Color = d["col"]
		_debris_buf[off + 12] = col.r; _debris_buf[off + 13] = col.g; _debris_buf[off + 14] = col.b; _debris_buf[off + 15] = 1.0
		dc += 1
	_debris_mm.visible_instance_count = dc
	if dc > 0:
		_debris_mm.buffer = _debris_buf

	var sc := 0
	for i in range(_sparks.size() - 1, -1, -1):
		var sp := _sparks[i]
		sp["t"] = float(sp["t"]) + dt
		if float(sp["t"]) >= float(sp["dur"]):
			_sparks.remove_at(i)
			continue
		var v: Vector3 = sp["v"]
		v.y -= float(sp.get("grav", 9.5)) * dt
		var p: Vector3 = sp["p"] + v * dt
		sp["p"] = p; sp["v"] = v
		var fade := 1.0 - float(sp["t"]) / float(sp["dur"])
		var s := float(sp["sz"]) * fade
		var off := sc * 16
		_sparks_buf[off] = s; _sparks_buf[off + 1] = 0.0; _sparks_buf[off + 2] = 0.0; _sparks_buf[off + 3] = p.x
		_sparks_buf[off + 4] = 0.0; _sparks_buf[off + 5] = s; _sparks_buf[off + 6] = 0.0; _sparks_buf[off + 7] = p.y
		_sparks_buf[off + 8] = 0.0; _sparks_buf[off + 9] = 0.0; _sparks_buf[off + 10] = s; _sparks_buf[off + 11] = p.z
		var col: Color = sp["col"]
		_sparks_buf[off + 12] = col.r; _sparks_buf[off + 13] = col.g; _sparks_buf[off + 14] = col.b; _sparks_buf[off + 15] = fade
		sc += 1
	_sparks_mm.visible_instance_count = sc
	if sc > 0:
		_sparks_mm.buffer = _sparks_buf

	var clc := 0
	for i in range(_slashes.size() - 1, -1, -1):
		var sl := _slashes[i]
		sl["t"] = float(sl["t"]) + dt
		if float(sl["t"]) >= float(sl["dur"]):
			_slashes.remove_at(i)
			continue
		var p: Vector3 = sl["p"]
		var u := clampf(float(sl["t"]) / float(sl["dur"]), 0.0, 1.0)
		var off := clc * 16
		_slashes_buf[off] = 1.0; _slashes_buf[off + 1] = 0.0; _slashes_buf[off + 2] = 0.0; _slashes_buf[off + 3] = p.x
		_slashes_buf[off + 4] = 0.0; _slashes_buf[off + 5] = 1.0; _slashes_buf[off + 6] = 0.0; _slashes_buf[off + 7] = p.y
		_slashes_buf[off + 8] = 0.0; _slashes_buf[off + 9] = 0.0; _slashes_buf[off + 10] = 1.0; _slashes_buf[off + 11] = p.z
		_slashes_buf[off + 12] = u; _slashes_buf[off + 13] = float(sl["dir"]); _slashes_buf[off + 14] = float(sl["tilt"]); _slashes_buf[off + 15] = float(sl["sc"])
		clc += 1
	_slashes_mm.visible_instance_count = clc
	if clc > 0:
		_slashes_mm.buffer = _slashes_buf

	var rc := 0
	for i in range(_rings.size() - 1, -1, -1):
		var rg := _rings[i]
		rg["t"] = float(rg["t"]) + dt
		if float(rg["t"]) >= float(rg["dur"]):
			_rings.remove_at(i)
			continue
		var p: Vector3 = rg["p"]
		var rad := float(rg["rad"])
		var u := clampf(float(rg["t"]) / float(rg["dur"]), 0.0, 1.0)
		var off := rc * 20
		_rings_buf[off] = rad; _rings_buf[off + 1] = 0.0; _rings_buf[off + 2] = 0.0; _rings_buf[off + 3] = p.x
		_rings_buf[off + 4] = 0.0; _rings_buf[off + 5] = 1.0; _rings_buf[off + 6] = 0.0; _rings_buf[off + 7] = p.y
		_rings_buf[off + 8] = 0.0; _rings_buf[off + 9] = 0.0; _rings_buf[off + 10] = rad; _rings_buf[off + 11] = p.z
		var col: Color = rg["col"]
		_rings_buf[off + 12] = col.r; _rings_buf[off + 13] = col.g; _rings_buf[off + 14] = col.b; _rings_buf[off + 15] = col.a
		_rings_buf[off + 16] = u; _rings_buf[off + 17] = float(rg["w"]); _rings_buf[off + 18] = float(rg["rise"]); _rings_buf[off + 19] = 0.0
		rc += 1
	_rings_mm.visible_instance_count = rc
	if rc > 0:
		_rings_mm.buffer = _rings_buf
