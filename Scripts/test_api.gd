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
## 测试用单位冻结效果
const FREEZE_UNIT : GameplayEffect = preload("res://game/content/effects/freeze_unit.tres")


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


## 结束当前战斗，并把时间倍率还原为 1
static func stop_battle() -> void:
	var window := _battle_window()
	if window != null:
		window.stop_battle_for_test()
	Engine.time_scale = 1.0


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
	return true


## 对已装备的某个魂灵施加冻结（用于测试仙子/魂灵冻结显示）
static func apply_soul_freeze(soul_name : String, seconds : float = 1.0, target : String = "player") -> bool:
	var unit := _find_unit(target)
	if unit == null or unit.brain == null or seconds <= 0.0:
		return false
	for ability in unit.brain.abilities:
		var charged := ability as ChargedAbility
		if charged != null and charged.ability_name == soul_name:
			return charged.apply_freeze(seconds)
	return false


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


## 设置全局时间倍率（0.1～20）
static func set_time_scale(scale : float) -> void:
	Engine.time_scale = clampf(scale, 0.1, 20.0)


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


#region 内部

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
