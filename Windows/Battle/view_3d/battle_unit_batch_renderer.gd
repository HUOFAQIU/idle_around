class_name BattleUnitBatchRenderer
extends RefCounted

var _owner: Node3D
var _material: ShaderMaterial
var _batches: Dictionary = {}


func init(owner: Node3D, unit_material: ShaderMaterial) -> void:
	_owner = owner
	_material = unit_material
	_batches.clear()


func has_batch(key: String) -> bool:
	return _batches.has(key)


func register_batch(key: String, mesh: Mesh, capacity: int) -> void:
	if mesh == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Batch_" + key
	mmi.multimesh = mm
	mmi.material_override = _material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mmi.extra_cull_margin = 16384.0
	_owner.add_child(mmi)

	var buf := PackedFloat32Array()
	buf.resize(capacity * 20)
	_batches[key] = {"mm": mm, "buf": buf, "cap": capacity, "cnt": 0}


func begin_frame() -> void:
	for key in _batches.keys():
		_batches[key]["cnt"] = 0


func push_unit(
	key: String,
	pos: Vector3,
	yaw: float,
	scale_val: float,
	anim_phase: float,
	swing: float,
	flash: float,
	move_blend: float
) -> void:
	if not _batches.has(key):
		return
	var batch: Dictionary = _batches[key]
	var cnt: int = batch["cnt"]
	if cnt >= int(batch["cap"]):
		return

	var buf: PackedFloat32Array = batch["buf"]
	var cy := cos(yaw) * scale_val
	var sy := sin(yaw) * scale_val
	var off := cnt * 20

	# invariant: buf[off+0..11] 是 3x4 变换基与平移
	buf[off + 0] = cy;   buf[off + 1] = 0.0;       buf[off + 2] = sy;   buf[off + 3] = pos.x
	buf[off + 4] = 0.0;  buf[off + 5] = scale_val; buf[off + 6] = 0.0;  buf[off + 7] = pos.y
	buf[off + 8] = -sy;  buf[off + 9] = 0.0;       buf[off + 10] = cy;  buf[off + 11] = pos.z
	# invariant: buf[off+12..15] 是顶点色乘子（白）
	buf[off + 12] = 1.0; buf[off + 13] = 1.0; buf[off + 14] = 1.0; buf[off + 15] = 1.0
	# invariant: buf[off+16..19] 对应 shader INSTANCE_CUSTOM
	buf[off + 16] = anim_phase
	buf[off + 17] = swing
	buf[off + 18] = flash
	buf[off + 19] = move_blend

	batch["cnt"] = cnt + 1


func flush() -> void:
	for key in _batches.keys():
		var batch: Dictionary = _batches[key]
		var mm: MultiMesh = batch["mm"]
		var cnt: int = batch["cnt"]
		mm.visible_instance_count = cnt
		if cnt > 0:
			mm.buffer = batch["buf"]


func get_total_visible_units() -> int:
	var total := 0
	for key in _batches.keys():
		total += int(_batches[key]["cnt"])
	return total
