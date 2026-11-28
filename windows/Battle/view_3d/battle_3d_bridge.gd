class_name Battle3DBridge
extends RefCounted

const SPARK_GOLD := Color(2.4, 1.7, 0.6)
const SPARK_BLOOD := Color(2.0, 0.65, 0.45)
const SOLDIER_SHATTER := Color(0.55, 0.68, 0.92)
const FX_BURN := Color(2.4, 0.85, 0.22, 0.95)
const FX_POISON := Color(0.55, 2.1, 0.45, 0.95)
const FX_FREEZE := Color(0.55, 1.85, 2.5, 0.95)
const FX_SHIELD := Color(0.65, 2.0, 2.4, 0.90)
const FX_HEAL := Color(0.45, 2.2, 0.85, 0.90)

const CLAW_SLASH_TAG := "Cue.Combat.ClawSlash"
const MAX_PLAYER_HIT_FX_PER_FRAME: int = 2
const MAX_ENEMY_HIT_FX_PER_FRAME: int = 8
const MAX_STATUS_FX_PER_FRAME: int = 10
const MAX_KILL_FX_PER_FRAME: int = 8
const MAX_KILL_SFX_PER_FRAME: int = 3

const CUE_STYLES := {
	"Cue.Status.Burn": {"color": FX_BURN, "radius": 1.15, "dur": 0.36, "rise": 0.35, "sparks": 4},
	"Cue.Combat.PoisonApply": {"color": FX_POISON, "radius": 1.25, "dur": 0.34, "rise": 0.15, "sparks": 4},
	"Cue.Status.Poison": {"color": FX_POISON, "radius": 1.05, "dur": 0.34, "rise": 0.25, "sparks": 3},
	"Cue.Status.Freeze": {"color": FX_FREEZE, "radius": 1.35, "dur": 0.42, "rise": 0.08, "sparks": 5},
	"Cue.Status.Shield": {"color": FX_SHIELD, "radius": 1.25, "dur": 0.40, "rise": 0.25, "sparks": 3},
	"Cue.Status.Heal": {"color": FX_HEAL, "radius": 1.20, "dur": 0.42, "rise": 0.65, "sparks": 4},
}

var _battle: BattleManager
var _fx: BattleFxPool
var _sfx: BattleSfxPool
var _to_3d: Callable
var _add_shake: Callable
var _on_enemy_killed: Callable
var _fx_frame: int = -1
var _player_hit_fx_count: int = 0
var _enemy_hit_fx_count: int = 0
var _status_fx_count: int = 0
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
	unit.asc.periodic_effect_ticked.connect(_on_periodic_effect_ticked.bind(unit))
	unit.asc.active_effect_added.connect(_on_active_effect_added.bind(unit))
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
	elif CUE_STYLES.has(tag):
		_play_cue_style(pos3, hit_pos, sc, CUE_STYLES[tag])


func _play_cue_style(pos3: Vector3, hit_pos: Vector3, sc: float, style: Dictionary) -> void:
	_reset_frame_fx_budget()
	if _status_fx_count >= MAX_STATUS_FX_PER_FRAME:
		return
	_status_fx_count += 1
	var col: Color = style["color"]
	var rad := float(style["radius"]) * clampf(sc, 0.8, 3.5)
	_fx.spawn_ring(pos3, col, rad, float(style["dur"]), 0.16, float(style["rise"]))
	_fx.spawn_status_particles(hit_pos, int(style["sparks"]), col, 1.9)


func _reset_frame_fx_budget() -> void:
	var frame := Engine.get_physics_frames()
	if frame != _fx_frame:
		_fx_frame = frame
		_player_hit_fx_count = 0
		_enemy_hit_fx_count = 0
		_status_fx_count = 0
		_kill_fx_count = 0
		_kill_sfx_count = 0


func _on_effect_received(_source_asc: AbilitySystemComponent, spec: GameplayEffectSpec, unit: BattleUnit) -> void:
	if spec == null or unit == null or not is_instance_valid(unit):
		return
	_reset_frame_fx_budget()
	var shield_delta := float(spec.calculated_deltas.get("shield", 0.0))
	var health_delta := float(spec.calculated_deltas.get("health", 0.0))
	if shield_delta > 0.0:
		var pos_s: Vector3 = _to_3d.call(unit.position)
		_play_cue_style(pos_s, pos_s + Vector3(0.0, 0.7, 0.0), 1.0, CUE_STYLES["Cue.Status.Shield"])
		return
	if health_delta > 0.0:
		var pos_h: Vector3 = _to_3d.call(unit.position)
		_play_cue_style(pos_h, pos_h + Vector3(0.0, 0.6, 0.0), 1.0, CUE_STYLES["Cue.Status.Heal"])
		return
	if health_delta >= 0.0 and shield_delta >= 0.0:
		return
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


func _on_active_effect_added(active_effect: ActiveGameplayEffect, unit: BattleUnit) -> void:
	if active_effect == null or unit == null or not is_instance_valid(unit) or unit.is_dead:
		return
	var def := active_effect.get_effect_def()
	if def == null:
		return
	var pos3: Vector3 = _to_3d.call(unit.position)
	var hh := unit.monster_data.hit_height if unit.monster_data != null else 0.75
	var sc := unit.monster_data.visual_scale if unit.monster_data != null else 1.0
	for tag in def.application_cue_tags:
		var key := String(tag)
		if CUE_STYLES.has(key):
			_play_cue_style(pos3, pos3 + Vector3(0.0, hh, 0.0), sc, CUE_STYLES[key])
			return
	if def.granted_tags.has(GameplayTags.State_Frozen):
		_play_cue_style(pos3, pos3 + Vector3(0.0, hh, 0.0), sc, CUE_STYLES["Cue.Status.Freeze"])


func _on_periodic_effect_ticked(_active_effect: ActiveGameplayEffect, spec: GameplayEffectSpec, unit: BattleUnit) -> void:
	if spec == null or unit == null or not is_instance_valid(unit) or unit.is_dead:
		return
	_reset_frame_fx_budget()
	if _status_fx_count >= MAX_STATUS_FX_PER_FRAME:
		return
	var def := spec.effect_def
	if def == null:
		return
	var col := Color(0, 0, 0, 0)
	for tag in def.periodic_cue_tags:
		var key := String(tag)
		if CUE_STYLES.has(key):
			col = CUE_STYLES[key]["color"]
			break
	if col.a <= 0.0:
		var tick := PeriodicStatusTickExecution.find(def)
		if tick == null:
			return
		var health_delta := float(spec.calculated_deltas.get("health", 0.0))
		col = FX_HEAL if health_delta > 0.0 else FX_BURN
	_status_fx_count += 1
	var pos3: Vector3 = _to_3d.call(unit.position)
	var hh := unit.monster_data.hit_height if unit.monster_data != null else 0.75
	_fx.spawn_status_particles(pos3 + Vector3(0.0, hh * 0.7, 0.0), 3, col, 1.7)


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
