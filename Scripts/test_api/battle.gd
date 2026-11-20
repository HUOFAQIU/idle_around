extends RefCounted
## TestAPI 战斗域：开战、刷怪、效果与战斗快照。
##
## 对外入口仍是 res://Scripts/test_api.gd 的 TestAPI。

const COMMON: GDScript = preload("res://Scripts/test_api/common.gd")

## 测试用灼烧效果：施加 + 周期
const BURN_APPLY : GameplayEffect = preload("res://base_mods/core/effects/burn_apply.tres")
const BURN_TICK : GameplayEffect = preload("res://base_mods/core/effects/burn_tick.tres")
## 测试用剧毒效果：施加 + 周期
const POISON_APPLY : GameplayEffect = preload("res://base_mods/core/effects/poison_apply.tres")
const POISON_TICK : GameplayEffect = preload("res://base_mods/core/effects/poison_tick.tres")
## 测试用生命再生效果：施加 + 周期
const REGEN_APPLY : GameplayEffect = preload("res://base_mods/core/effects/regen_apply.tres")
const REGEN_TICK : GameplayEffect = preload("res://base_mods/core/effects/regen_tick.tres")
## 测试用单位冻结效果
const FREEZE_UNIT : GameplayEffect = preload("res://base_mods/core/effects/freeze_unit.tres")

static func start_battle(map_id : StringName = MapCatalog.FOREST_MAP_ID) -> bool:
	var window := _battle_window()
	if window == null:
		push_warning("TestAPI：找不到 BattleWindow")
		return false
	var item := MapCatalog.make_map_item(map_id)
	if item == null:
		push_warning("TestAPI：地图不存在 %s" % map_id)
		return false
	window.start_map_battle(item)
	return true


static func stop_battle() -> void:
	var window := _battle_window()
	if window != null:
		window.stop_battle()


static func spawn_monster(monster_id : StringName) -> bool:
	var window := _battle_window()
	if window == null:
		return false
	return window.spawn_monster_for_test(monster_id)


static func apply_burn(target : String = "player") -> bool:
	return _apply_dot(BURN_APPLY, BURN_TICK, target)


static func apply_poison(target : String = "player") -> bool:
	return _apply_dot(POISON_APPLY, POISON_TICK, target)


static func apply_regen(target : String = "player") -> bool:
	return _apply_dot(REGEN_APPLY, REGEN_TICK, target)


static func apply_freeze(target : String = "player", seconds : float = 3.0) -> bool:
	var unit: BattleUnit = COMMON.find_unit(target)
	if unit == null or unit.asc == null or seconds <= 0.0:
		return false
	var context := GameplayEffectContext.new(unit, unit)
	context.target_data.append_node(unit)
	var spec := GameplayEffectSpec.new(FREEZE_UNIT, context)
	spec.duration = seconds
	unit.asc.apply_effect_spec(spec)
	# 真实冻结会广播 FREEZE_APPLIED；测试接口保持一致，便于验证冻结触发器
	unit.notify_freeze_applied(unit)
	return true


static func play_claw_cue(target : String = "enemy", direction : int = 1) -> bool:
	var unit: BattleUnit = COMMON.find_unit(target)
	if unit == null or unit.asc == null:
		return false
	unit.asc.execute_cue(&"Cue.Combat.ClawSlash", {"direction": 1.0 if direction >= 0 else -1.0})
	return true


static func apply_soul_freeze(soul_name : String, seconds : float = 1.0, target : String = "player") -> bool:
	if seconds <= 0.0:
		return false
	var charged := _find_equipped_ability(soul_name, target)
	if charged == null:
		return false
	return charged.apply_freeze(seconds)


static func simulate_soul_used(soul_name : String, target : String = "player") -> bool:
	var charged := _find_equipped_ability(soul_name, target)
	var unit: BattleUnit = COMMON.find_unit(target)
	if charged == null or unit == null:
		return false
	unit.notify_soul_used(charged)
	return true


static func charge_soul(soul_name : String, seconds : float, target : String = "player") -> bool:
	if seconds <= 0.0:
		return false
	var charged := _find_equipped_ability(soul_name, target)
	if charged == null:
		return false
	charged.add_charge(seconds)
	return true


static func damage_unit(target : String = "player", amount : float = 1.0) -> bool:
	var unit: BattleUnit = COMMON.find_unit(target)
	amount = floorf(amount)
	if unit == null or unit.asc == null or amount <= 0.0:
		return false
	var effect := GameplayEffect.new()
	effect.policy = GameplayEffect.DurationPolicy.INSTANT
	var modifier := GameplayEffectModifier.new()
	modifier.attribute_name = "health"
	modifier.operation = GameplayEffectModifier.Operation.ADD
	modifier.magnitude = -amount
	var modifiers : Array[GameplayEffectModifier] = [modifier]
	effect.modifiers = modifiers
	unit.asc.apply_gameplay_effect(effect, unit.asc)
	return true


static func has_status(tag : StringName, target : String = "player") -> bool:
	var unit: BattleUnit = COMMON.find_unit(target)
	return unit != null and unit.asc != null and unit.asc.has_tag(tag)


static func get_battle_state() -> Dictionary:
	var window := _battle_window()
	if window == null:
		return {"running": false}
	return window.get_test_state()


## 当前战斗已完成的物理 tick 数；没有战斗时返回 0
static func get_battle_tick() -> int:
	var battle := _active_battle()
	return 0 if battle == null else battle.tick_count()


## 暂停战斗仿真：引擎物理帧不再推进，改用 step_battle()
static func pause_battle() -> bool:
	var session := _active_session()
	return session != null and session.set_manual_time(true)


## 恢复战斗仿真
static func resume_battle() -> bool:
	var session := _active_session()
	return session != null and session.set_manual_time(false)


## 手动推进战斗 tick；只在 pause_battle() 之后有效
static func step_battle(ticks : int = 1) -> bool:
	var session := _active_session()
	return session != null and session.step_ticks(ticks)


## 战斗时钟快照
static func get_battle_clock() -> Dictionary:
	var session := _active_session()
	if session == null or session.battle == null or session.battle.clock == null:
		return {}
	var clock := session.battle.clock
	return {
		"manual": clock.manual,
		"tick_seconds": clock.tick_seconds,
		"ticks_per_second": clock.ticks_per_second,
	}


static func get_enemy_count() -> int:
	var battle := _active_battle()
	return 0 if battle == null else battle.enemy_count()


static func get_nearest_enemy_distance() -> float:
	var battle := _active_battle()
	if battle == null or battle.player == null:
		return -1.0
	var nearest := INF
	for enemy in battle.enemies:
		if enemy == null or enemy.is_dead:
			continue
		nearest = minf(nearest, enemy.distance_to_unit(battle.player))
	return nearest if nearest != INF else -1.0


static func get_enemies_in_attack_range() -> int:
	var battle := _active_battle()
	if battle == null:
		return 0
	var count := 0
	for enemy in battle.enemies:
		if enemy != null and not enemy.is_dead and enemy.is_in_attack_range(battle.player):
			count += 1
	return count


static func get_perf_snapshot() -> Dictionary:
	var battle := _active_battle()
	if battle == null:
		return {}
	var tree := Engine.get_main_loop() as SceneTree
	return {
		"fps": Engine.get_frames_per_second(),
		"elapsed": battle.elapsed_seconds(),
		"node_count": tree.get_node_count() if tree != null else 0,
		"enemies": battle.enemy_count(),
		"enemies_in_attack_range": get_enemies_in_attack_range(),
		"nearest_enemy_distance": get_nearest_enemy_distance(),
	}


static func get_battle_log() -> String:
	if InfoWindow.instance == null:
		return ""
	return InfoWindow.instance.get_log_text()


static func get_fps_text() -> String:
	var window := _battle_window()
	return "" if window == null else window.get_fps_text_for_test()


static func _apply_dot(
	apply : GameplayEffect, tick : GameplayEffect, target : String
) -> bool:
	var unit: BattleUnit = COMMON.find_unit(target)
	if unit == null or unit.asc == null:
		return false
	unit.asc.apply_gameplay_effect(apply)
	unit.asc.apply_gameplay_effect(tick)
	return true


static func _active_battle() -> BattleManager:
	var window := _battle_window()
	return window.get_battle() if window != null else null


static func _active_session() -> BattleSession:
	var window := _battle_window()
	return window.get_battle_session() if window != null else null


## 按显示名找某个单位已装备的魂灵技能
static func _find_equipped_ability(soul_name : String, target : String) -> ChargedAbility:
	var unit: BattleUnit = COMMON.find_unit(target)
	if unit == null or unit.brain == null:
		return null
	for ability in unit.brain.abilities:
		var charged := ability as ChargedAbility
		if charged != null and charged.ability_name == soul_name:
			return charged
	return null


static func _battle_window() -> BattleWindow:
	return COMMON.find_node_in_scene(BattleWindow) as BattleWindow
