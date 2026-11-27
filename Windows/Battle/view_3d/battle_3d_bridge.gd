class_name Battle3DBridge
extends RefCounted

const SPARK_GOLD := Color(2.4, 1.7, 0.6)
const SPARK_BLOOD := Color(2.0, 0.65, 0.45)
const SOLDIER_SHATTER := Color(0.55, 0.68, 0.92)
const CLAW_SLASH_TAG := "Cue.Combat.ClawSlash"
const MAX_PLAYER_HIT_FX_PER_FRAME: int = 2
const MAX_ENEMY_HIT_FX_PER_FRAME: int = 8
const MAX_KILL_FX_PER_FRAME: int = 8
const MAX_KILL_SFX_PER_FRAME: int = 3

var _battle: BattleManager
var _fx: BattleFxPool
var _sfx: BattleSfxPool
var _to_3d: Callable
var _add_shake: Callable
var _on_enemy_killed: Callable
var _fx_frame: int = -1
var _player_hit_fx_count: int = 0
var _enemy_hit_fx_count: int = 0
var _kill_fx_count: int = 0
var _kill_sfx_count: int = 0


func _init(
	battle: BattleManager,
	fx: BattleFxPool,
	sfx: BattleSfxPool,
	to_3d: Callable,
	add_shake: Callable,
	on_enemy_killed: Callable
) -> void:
	_battle = battle
	_fx = fx
	_sfx = sfx
	_to_3d = to_3d
	_add_shake = add_shake
	_on_enemy_killed = on_enemy_killed
	if _battle == null:
		return
	_battle.events.unit_asc_ready.connect(_on_unit_asc_ready)
	_battle.events.emitted.connect(_on_event)


func _on_unit_asc_ready(unit: BattleUnit) -> void:
	if unit == null or unit.asc == null:
		return
	unit.asc.effect_received.connect(_on_effect_received.bind(unit))
	unit.died.connect(_on_unit_died)


func _on_event(event: BattleEvent) -> void:
	if event == null:
		return
	if event.category == BattleEvent.CATEGORY_CUE and event.type == "hit_cue":
		_on_hit_cue(event)
	elif event.category == BattleEvent.CATEGORY_CAST and event.type == "release":
		var actor := event.fields.get("actor_unit") as BattleUnit
		if actor != null and is_instance_valid(actor):
			actor.swing = 1.0


func _on_hit_cue(event: BattleEvent) -> void:
	var target := event.fields.get("target_unit") as BattleUnit
	if target == null or not is_instance_valid(target):
		return
	var actor := event.fields.get("actor_unit") as BattleUnit
	if actor != null and is_instance_valid(actor):
		var delta := target.position - actor.position
		if delta.length_squared() > 0.001:
			actor.yaw = atan2(delta.x, delta.y)
		actor.swing = 1.0

	var tag := String(event.fields.get("cue_tag", ""))
	var pos3: Vector3 = _to_3d.call(target.position)
	var hh := target.monster_data.hit_height if target.monster_data != null else 0.75
	var sc := target.monster_data.visual_scale if target.monster_data != null else 1.0
	var hit_pos := pos3 + Vector3(0.0, hh, 0.0)
	if tag == CLAW_SLASH_TAG:
		var dir := float(event.fields.get("direction", 1.0))
		_fx.spawn_claw_slash(hit_pos, dir, clampf(sc * 1.45, 1.35, 2.2))
		_fx.spawn_sparks(hit_pos, 4, SPARK_GOLD, 4.0)
		_sfx.play("sword", 0.48)


func _reset_frame_fx_budget() -> void:
	var frame := Engine.get_physics_frames()
	if frame != _fx_frame:
		_fx_frame = frame
		_player_hit_fx_count = 0
		_enemy_hit_fx_count = 0
		_kill_fx_count = 0
		_kill_sfx_count = 0


func _on_effect_received(_source_asc: AbilitySystemComponent, spec: GameplayEffectSpec, unit: BattleUnit) -> void:
	if spec == null or unit == null or not is_instance_valid(unit):
		return
	_reset_frame_fx_budget()
	if unit.team == BattleUnit.Team.ENEMY:
		unit.flash = 0.85
		if _enemy_hit_fx_count >= MAX_ENEMY_HIT_FX_PER_FRAME:
			return
		_enemy_hit_fx_count += 1
		var pos3: Vector3 = _to_3d.call(unit.position)
		var hh := unit.monster_data.hit_height if unit.monster_data != null else 0.6
		_fx.spawn_sparks(pos3 + Vector3(0.0, hh, 0.0), 3, SPARK_GOLD, 3.4)
	else:
		unit.flash = 0.50
		if _player_hit_fx_count >= MAX_PLAYER_HIT_FX_PER_FRAME:
			return
		_player_hit_fx_count += 1
		var pos3: Vector3 = _to_3d.call(unit.position)
		_fx.spawn_sparks(pos3 + Vector3(0.0, 0.9, 0.0), 3, SPARK_BLOOD, 3.0)
		_sfx.play("clash", 0.30)


func _on_unit_died(unit: BattleUnit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	_reset_frame_fx_budget()
	if unit.team == BattleUnit.Team.ENEMY:
		if _on_enemy_killed.is_valid():
			_on_enemy_killed.call()
		if _kill_fx_count < MAX_KILL_FX_PER_FRAME:
			_kill_fx_count += 1
			var pos3: Vector3 = _to_3d.call(unit.position)
			var sc := unit.monster_data.visual_scale if unit.monster_data != null else 1.0
			var col := unit.monster_data.debris_color if unit.monster_data != null else SPARK_GOLD
			var knock := Vector3(pos3.x, 0.0, pos3.z).normalized() * 2.8
			_fx.spawn_shatter(pos3, sc, col, knock)
		if _kill_sfx_count < MAX_KILL_SFX_PER_FRAME:
			_kill_sfx_count += 1
			_sfx.play("kill", 0.42)
			if _add_shake.is_valid():
				_add_shake.call(0.07, 0.40)
	else:
		var pos3: Vector3 = _to_3d.call(unit.position)
		_fx.spawn_shatter(pos3, 1.2, SOLDIER_SHATTER, Vector3(0.0, 2.5, 0.0))
		_sfx.play("kill", 0.65)
		if _add_shake.is_valid():
			_add_shake.call(0.55, 0.55)
