@tool
class_name UnitAnimPreview
extends Node3D

enum PreviewMode {
	IDLE,
	MOVE,
	ATTACK_LOOP,
	MANUAL_ATTACK,
}

const UNIT_SHADER: Shader = preload("res://Windows/Battle/shaders/lit_unit.gdshader")
const TEX_ALBEDO_DIRT: Texture2D = preload("res://Windows/Battle/assets/textures/albedo_00_dirt.png")
const DEFAULT_MONSTER: MonsterData = preload("res://base_mods/core/monsters/fu/fu_monster.tres")
const FALLBACK_GROUND_COLOR := Color(0.28, 0.42, 0.20, 1.0)
const WHITE_COLOR := Color(1.0, 1.0, 1.0, 1.0)

@export_group("预览目标")
## 拖入任意 MonsterData（自动读取 mesh_3d、visual_scale 与 anim_config）
@export var monster_data: MonsterData = DEFAULT_MONSTER:
	set(value):
		monster_data = value
		_rebuild_unit()
## 手动覆盖网格（不填时优先使用 monster_data.mesh_3d）
@export var override_mesh: Mesh:
	set(value):
		override_mesh = value
		_rebuild_unit()
## 手动覆盖动画配置（不填时优先使用 monster_data.anim_config）
@export var override_anim: UnitAnimConfig:
	set(value):
		override_anim = value
		_apply_anim_params()
## 预览缩放倍率（0 表示使用 monster_data.visual_scale）
@export_range(0.0, 4.0, 0.05) var override_scale: float = 0.0

@export_group("动画控制")
## 预览动画状态：待机 / 移动 / 循环攻击 / 手动拉进度
@export var preview_mode: PreviewMode = PreviewMode.ATTACK_LOOP
## 移动模拟速度（用于驱动移动相位推进）
@export_range(0.5, 8.0, 0.1) var preview_move_speed: float = 2.6
## 手动攻击进度（仅 MANUAL_ATTACK 模式生效，0=起手，0.52=命中，1=收招）
@export_range(0.0, 1.0, 0.01) var manual_attack_u: float = 0.52
## 模拟周期受击闪白
@export var test_hit_flash: bool = false
## 旋转展示角度（度）
@export_range(-180.0, 180.0, 1.0) var yaw_degrees: float = 0.0

var _mmi: MultiMeshInstance3D
var _mm: MultiMesh
var _mat: ShaderMaterial
var _buf := PackedFloat32Array()
var _phase: float = 0.0
var _swing: float = 0.0
var _atk_wait: float = 0.0
var _flash: float = 0.0
var _flash_cd: float = 0.0


func _ready() -> void:
	_setup_stage()
	_rebuild_unit()


func _process(delta: float) -> void:
	if _mm == null or _mat == null:
		return
	var dt := minf(delta, 0.05)
	var cfg := _active_anim_config()
	cfg.apply_to_material(_mat)

	var mv := 0.0
	match preview_mode:
		PreviewMode.IDLE:
			_phase += dt * 2.0
			_swing = 0.0
		PreviewMode.MOVE:
			_phase += dt * preview_move_speed * cfg.move_phase_scale
			_swing = 0.0
			mv = 1.0
		PreviewMode.ATTACK_LOOP:
			_phase += dt * 2.2
			if _swing > 0.0:
				_swing = maxf(0.0, _swing - dt * cfg.attack_speed)
			else:
				_atk_wait -= dt
				if _atk_wait <= 0.0:
					_swing = 1.0
					_atk_wait = 0.45
		PreviewMode.MANUAL_ATTACK:
			_swing = clampf(1.0 - manual_attack_u, 0.0, 1.0)

	if test_hit_flash:
		_flash_cd -= dt
		if _flash_cd <= 0.0:
			_flash = 0.9
			_flash_cd = 0.85
		_flash = maxf(0.0, _flash - dt * cfg.flash_decay)
	else:
		_flash = 0.0

	_push_preview_instance(mv)


func _setup_stage() -> void:
	if get_node_or_null("PreviewGround") == null:
		var ground := MeshInstance3D.new()
		ground.name = "PreviewGround"
		var pm := PlaneMesh.new()
		pm.size = Vector2(6.0, 6.0)
		ground.mesh = pm
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = FALLBACK_GROUND_COLOR
		gmat.roughness = 0.92
		ground.material_override = gmat
		add_child(ground)

	if _mmi == null:
		_mmi = get_node_or_null("PreviewUnit") as MultiMeshInstance3D
	if _mmi == null:
		_mmi = MultiMeshInstance3D.new()
		_mmi.name = "PreviewUnit"
		add_child(_mmi)

	_mat = ShaderMaterial.new()
	_mat.shader = UNIT_SHADER
	var tex_arr := Texture2DArray.new()
	var img := TEX_ALBEDO_DIRT.get_image()
	if img != null:
		tex_arr.create_from_images([img])
		_mat.set_shader_parameter("u_tex_a", tex_arr)
	_mmi.material_override = _mat
	_buf.resize(20)


func _rebuild_unit() -> void:
	if _mmi == null:
		return
	var mesh := override_mesh
	if mesh == null and monster_data != null:
		mesh = monster_data.mesh_3d
	if mesh == null:
		_mmi.multimesh = null
		_mm = null
		return
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = mesh
	_mm.instance_count = 1
	_mm.visible_instance_count = 1
	_mmi.multimesh = _mm
	_apply_anim_params()
	_push_preview_instance(0.0)


func _apply_anim_params() -> void:
	if _mat == null:
		return
	_active_anim_config().apply_to_material(_mat)


func _active_anim_config() -> UnitAnimConfig:
	if override_anim != null:
		return override_anim
	if monster_data != null and monster_data.anim_config != null:
		return monster_data.anim_config
	return UnitAnimConfig.new()


func _push_preview_instance(mv: float) -> void:
	if _mm == null:
		return
	var sc := override_scale
	if sc <= 0.0:
		sc = monster_data.visual_scale if monster_data != null else 1.0
	var yaw := deg_to_rad(yaw_degrees)
	var cy := cos(yaw) * sc
	var sy := sin(yaw) * sc
	_buf[0] = cy; _buf[1] = 0.0; _buf[2] = sy; _buf[3] = 0.0
	_buf[4] = 0.0; _buf[5] = sc; _buf[6] = 0.0; _buf[7] = 0.0
	_buf[8] = -sy; _buf[9] = 0.0; _buf[10] = cy; _buf[11] = 0.0
	_buf[12] = WHITE_COLOR.r; _buf[13] = WHITE_COLOR.g; _buf[14] = WHITE_COLOR.b; _buf[15] = WHITE_COLOR.a
	_buf[16] = _phase
	_buf[17] = _swing
	_buf[18] = _flash
	_buf[19] = mv
	_mm.buffer = _buf
