class_name TestAPI
extends RefCounted
## AI 测试入口：集中暴露稳定的测试方法。
##
## 约定：新增功能/内容时，在这里补测试方法，并更新 `DOC/指南/AI测试接口.md`。
## 这些方法会改运行时状态，只在测试/探针里用，不要接入正式玩法。

const WAREHOUSE : String = "inventory_0"
## 部位 → 魂灵窗口容器名（见 equipment_window.tscn）
const SOUL_CELLS := {
	"HEADSOUL": "cell_0",
	"TORSOSOUL": "cell_1",
	"ARMSSOUL": "cell_2",
	"LEGSSOUL": "cell_3",
}
## 测试用灼烧效果：施加 + 周期
const BURN_APPLY : GameplayEffect = preload("res://game/content/effects/burn_apply.tres")
const BURN_TICK : GameplayEffect = preload("res://game/content/effects/burn_tick.tres")
## 测试用剧毒效果：施加 + 周期
const POISON_APPLY : GameplayEffect = preload("res://game/content/effects/poison_apply.tres")
const POISON_TICK : GameplayEffect = preload("res://game/content/effects/poison_tick.tres")
## 测试用生命再生效果：施加 + 周期
const REGEN_APPLY : GameplayEffect = preload("res://game/content/effects/regen_apply.tres")
const REGEN_TICK : GameplayEffect = preload("res://game/content/effects/regen_tick.tres")
## 测试用单位冻结效果
const FREEZE_UNIT : GameplayEffect = preload("res://game/content/effects/freeze_unit.tres")
## 温泉灼烧效果：用于预览再生 = 灼烧
const WEN_QUAN_BURN_APPLY : GameplayEffect = preload("res://game/content/effects/wen_quan_burn_apply.tres")


#region 背包 / 见闻

## 按 registry ID 把魂灵放进指定容器（默认仓库）
static func add_soul(id : StringName, container : String = WAREHOUSE) -> bool:
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % id)
		return false
	return GBIS.add_item(container, soul)


## 装备一颗魂灵。part 为空时按魂灵自身部位；ANY 魂灵依次尝试四个部位。
static func equip_soul(id : StringName, part : String = "") -> bool:
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % id)
		return false
	if part.is_empty():
		if soul.equip_part == "ANY":
			for soul_part in SOUL_CELLS:
				var any_cell : String = SOUL_CELLS[soul_part]
				if GBIS.add_item(any_cell, soul):
					return true
			return false
		part = soul.equip_part
	var cell : String = SOUL_CELLS.get(part, "")
	if cell.is_empty():
		push_warning("TestAPI：未知部位 %s" % part)
		return false
	return GBIS.add_item(cell, soul)


## 清空容器并刷新视图
static func clear_container(container : String) -> void:
	var data := ContainerRepository.instance.get_container(container)
	if data == null:
		return
	data.clear()
	GBIS.sig_inv_refresh.emit()


## 返回容器内物品名（同名物品会出现多次）
static func get_container_items(container : String) -> Array[String]:
	var names : Array[String] = []
	var data := ContainerRepository.instance.get_container(container)
	if data == null:
		return names
	for item in data.items:
		if item != null:
			names.append(item.item_name)
	return names


## 临时切换见闻“全部已解锁”；不改存档
static func set_unlock_all(enabled : bool) -> void:
	CollectionDB.set_unlock_all_for_testing(enabled)


## 真实已解锁的 registry ID（不受全解锁开关影响）
static func get_seen_ids(kind : int) -> Array[StringName]:
	return CollectionDB.get_seen_ids(kind)


static func is_seen(kind : int, id : StringName) -> bool:
	return CollectionDB.is_seen(kind, id)


static func get_soul_ids() -> Array[StringName]:
	return CollectionDB.get_soul_ids()


## 魂灵类型（registry ID），例如 &"Soul.types.RealEstate"
static func get_soul_types(id : StringName) -> Array[StringName]:
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		return []
	return soul.types.duplicate()


## 魂灵标签（见闻筛选 registry ID），例如 &"Soul.tags.Small"
static func get_soul_tags(id : StringName) -> Array[StringName]:
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		return []
	return soul.tags.duplicate()


static func get_monster_ids() -> Array[StringName]:
	return CollectionDB.get_monster_ids()

#endregion


#region 战斗

## 显示战斗窗口并开战；monster_id 非空时首只必刷该怪
static func start_battle(monster_id : StringName = &"") -> bool:
	var window := _battle_window()
	if window == null:
		push_warning("TestAPI：找不到 BattleWindow")
		return false
	if not window.visible:
		window.show()
	window.start_battle_for_test(monster_id)
	return true


## 结束当前战斗
static func stop_battle() -> void:
	var window := _battle_window()
	if window != null:
		window.stop_battle_for_test()


## 在远处空位刷一只指定怪物
static func spawn_monster(monster_id : StringName) -> bool:
	var window := _battle_window()
	if window == null:
		return false
	return window.spawn_monster_for_test(monster_id)


## 对战斗中的单位施加灼烧（用于测试状态与火焰 Cue）
static func apply_burn(target : String = "player") -> bool:
	var unit := _find_unit(target)
	if unit == null or unit.asc == null:
		return false
	unit.asc.apply_gameplay_effect(BURN_APPLY)
	unit.asc.apply_gameplay_effect(BURN_TICK)
	return true


## 对战斗中的单位施加剧毒（用于测试毒液飞溅与中毒光环 Cue）
static func apply_poison(target : String = "player") -> bool:
	var unit := _find_unit(target)
	if unit == null or unit.asc == null:
		return false
	unit.asc.apply_gameplay_effect(POISON_APPLY)
	unit.asc.apply_gameplay_effect(POISON_TICK)
	return true


## 对战斗中的单位施加生命再生（用于验证剧毒/再生相减）
static func apply_regen(target : String = "player") -> bool:
	var unit := _find_unit(target)
	if unit == null or unit.asc == null:
		return false
	unit.asc.apply_gameplay_effect(REGEN_APPLY)
	unit.asc.apply_gameplay_effect(REGEN_TICK)
	return true


## 按给定灼烧值预览温泉再生；不改运行时资源，用于验证“再生 = 灼烧”的派生关系
static func preview_wen_quan_regen(burn_amount : float = 24.0) -> float:
	var burn_effect := WEN_QUAN_BURN_APPLY.duplicate(true) as GameplayEffect
	var burn_status : StatusApplyExecution = null
	for execution in burn_effect.executions:
		if execution is StatusApplyExecution and (execution as StatusApplyExecution).attribute_name == "burn":
			burn_status = execution as StatusApplyExecution
			break
	if burn_status == null:
		return 0.0
	burn_status.base_amount = burn_amount
	var regen_execution := RegenFromBurnExecution.new()
	regen_execution.burn_effect = burn_effect
	var spec := GameplayEffectSpec.new(burn_effect, null)
	var result := regen_execution.execute(spec, null)
	return float(result.get("regen", 0.0))


## 对战斗中的单位施加冻结（用于测试冻结 Cue 与状态标签）
static func apply_freeze(target : String = "player", seconds : float = 3.0) -> bool:
	var unit := _find_unit(target)
	if unit == null or unit.asc == null or seconds <= 0.0:
		return false
	var context := GameplayEffectContext.new(unit, unit)
	context.target_data.append_node(unit)
	var spec := GameplayEffectSpec.new(FREEZE_UNIT, context)
	spec.duration = seconds
	unit.asc.apply_effect_spec(spec)
	# 真实冻结会广播 FREEZE_APPLIED；测试接口保持一致，便于验证温泉/冷冻间
	unit.notify_freeze_applied(unit)
	return true


## 对已装备的某个魂灵施加冻结（用于测试仙子/魂灵冻结显示）
static func apply_soul_freeze(soul_name : String, seconds : float = 1.0, target : String = "player") -> bool:
	if seconds <= 0.0:
		return false
	var charged := _find_equipped_ability(soul_name, target)
	if charged == null:
		return false
	return charged.apply_freeze(seconds)


## 模拟某个已装备魂灵被“使用”一次（不动冷却），用于确定性地测 OTHER_SOUL_USED 触发器
static func simulate_soul_used(soul_name : String, target : String = "player") -> bool:
	var charged := _find_equipped_ability(soul_name, target)
	var unit := _find_unit(target)
	if charged == null or unit == null:
		return false
	unit.notify_soul_used(charged)
	return true


## 给已装备的某个魂灵直接充能（秒）
static func charge_soul(soul_name : String, seconds : float, target : String = "player") -> bool:
	if seconds <= 0.0:
		return false
	var charged := _find_equipped_ability(soul_name, target)
	if charged == null:
		return false
	charged.add_charge(seconds)
	return true


## 对单位造成伤害（用于把生命值打到阈值以下，测试半血触发）
static func damage_unit(target : String = "player", amount : float = 1.0) -> bool:
	var unit := _find_unit(target)
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


## 单位当前是否拥有某个状态标签
static func has_status(tag : StringName, target : String = "player") -> bool:
	var unit := _find_unit(target)
	return unit != null and unit.asc != null and unit.asc.has_tag(tag)


## 当前战斗快照；没有战斗时 running = false
static func get_battle_state() -> Dictionary:
	var window := _battle_window()
	if window == null:
		return {"running": false}
	return window.get_test_state()


## 当前场上存活敌人数
static func get_enemy_count() -> int:
	var window := _battle_window()
	if window == null or window._battle == null:
		return 0
	return window._battle.enemy_count()


## 离角色最近的敌人还有多远（像素）；没有敌人时返回 -1
static func get_nearest_enemy_distance() -> float:
	var window := _battle_window()
	if window == null or window._battle == null or window._battle.player == null:
		return -1.0
	var nearest := INF
	for enemy in window._battle.enemies:
		if enemy == null or enemy.is_dead:
			continue
		nearest = minf(nearest, enemy.distance_to_unit(window._battle.player))
	return nearest if nearest != INF else -1.0


## 当前有多少敌人在角色攻击范围内（即时制下只有这些怪才会开始充能）
static func get_enemies_in_attack_range() -> int:
	var window := _battle_window()
	if window == null or window._battle == null:
		return 0
	var count := 0
	for enemy in window._battle.enemies:
		if enemy != null and not enemy.is_dead and enemy.is_in_attack_range(window._battle.player):
			count += 1
	return count


## 性能快照：FPS、节点数、敌人数、范围内敌人数、最近距离
static func get_perf_snapshot() -> Dictionary:
	var window := _battle_window()
	if window == null or window._battle == null:
		return {}
	var tree := Engine.get_main_loop() as SceneTree
	return {
		"fps": Engine.get_frames_per_second(),
		"elapsed": window._battle.elapsed_seconds(),
		"node_count": tree.get_node_count() if tree != null else 0,
		"enemies": window._battle.enemy_count(),
		"enemies_in_attack_range": get_enemies_in_attack_range(),
		"nearest_enemy_distance": get_nearest_enemy_distance(),
	}


## 当前战斗日志纯文本
static func get_battle_log() -> String:
	if InfoWindow.instance == null:
		return ""
	return InfoWindow.instance.log_label.get_parsed_text()


## 战斗窗口右上角的 FPS 文本
static func get_fps_text() -> String:
	var window := _battle_window()
	return "" if window == null else window.get_fps_text_for_test()

#endregion


#region 调试 / 遥测

## 最近调试事件；category 为空时返回全部
static func get_debug_events(category : String = "", limit : int = 200) -> Array:
	var filter : Dictionary = {}
	if not category.is_empty():
		filter["category"] = category
	return CombatTelemetry.query(filter, limit)


## 调试统计：缓冲大小、丢失数、当前场次、关注单位等
static func get_debug_stats() -> Dictionary:
	return CombatTelemetry.get_stats()


## 当前战斗快照（玩家完整详情，敌人摘要）
static func get_debug_snapshot() -> Dictionary:
	return CombatSnapshot.build(CombatTelemetry.current_battle)


## 某颗已装备魂灵的运行期状态；找不到返回空字典
static func get_soul_runtime(soul_name : String, target : String = "player") -> Dictionary:
	var unit := _find_unit(target)
	if unit == null:
		return {}
	for runtime in unit.loadout:
		if runtime != null and runtime.display_name() == soul_name:
			return CombatSnapshot.soul_runtime(runtime)
	return {}


## 某颗魂灵的触发器状态列表
static func get_trigger_state(soul_name : String, target : String = "player") -> Array:
	var unit := _find_unit(target)
	if unit == null:
		return []
	var result : Array = []
	for trigger in CombatSnapshot.triggers(unit):
		if String(trigger.get("source", "")) == soul_name:
			result.append(trigger)
	return result


## 清空调试事件缓冲；不影响战斗
static func clear_debug_events() -> void:
	CombatTelemetry.clear()


## 导出当前调试事件为 JSONL；返回绝对路径
static func export_debug_log(path : String = "user://debug/test.jsonl") -> String:
	return CombatTelemetry.export_jsonl(path)


## 开关遥测录制；关闭后 record() 直接返回
static func set_debug_recording(enabled : bool) -> void:
	CombatTelemetry.set_enabled(enabled)


## 把某个单位设为“关注单位”：详细事件只记录它
static func watch_unit_for_debug(target : String = "player") -> bool:
	var unit := _find_unit(target)
	if unit == null:
		return false
	CombatTelemetry.watch_unit(unit)
	return true

#endregion


#region 内部

## 按显示名找某个单位已装备的魂灵技能
static func _find_equipped_ability(soul_name : String, target : String) -> ChargedAbility:
	var unit := _find_unit(target)
	if unit == null or unit.brain == null:
		return null
	for ability in unit.brain.abilities:
		var charged := ability as ChargedAbility
		if charged != null and charged.ability_name == soul_name:
			return charged
	return null


## target："player" / "enemy" / 单位名
static func _find_unit(target : String) -> BattleUnit:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root : Node = tree.current_scene
	if root == null:
		root = tree.root
	for node in root.find_children("*", "", true, false):
		if not node is BattleUnit:
			continue
		var unit := node as BattleUnit
		if unit.is_dead or unit.asc == null:
			continue
		if target == "player" and unit.team == BattleUnit.Team.PLAYER:
			return unit
		if target == "enemy" and unit.team == BattleUnit.Team.ENEMY:
			return unit
		if unit.unit_name == target:
			return unit
	return null


static func _battle_window() -> BattleWindow:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root : Node = tree.current_scene
	if root == null:
		root = tree.root
	for node in root.find_children("*", "", true, false):
		if node is BattleWindow:
			return node as BattleWindow
	return null

#endregion
