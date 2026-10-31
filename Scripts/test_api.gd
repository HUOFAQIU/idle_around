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

#endregion


#region 内部

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
