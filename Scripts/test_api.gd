class_name TestAPI
extends RefCounted
## AI 测试入口：集中暴露稳定的测试方法。
##
## 约定：新增功能/内容时，在这里补测试方法，并更新 `DOC/指南/AI测试接口.md`。
## 这些方法会改运行时状态，只在测试/探针里用，不要接入正式玩法。

## 容器名集中定义；用 preload 而不是全局类名，保证 --script 无头模式也能解析
const CONTAINER_IDS: GDScript = preload("res://Scripts/container_ids.gd")
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
## 色板脚本：用于按常量名取色
const GAME_COLORS_SCRIPT : GDScript = preload("res://Scripts/game_colors.gd")


#region 颜色

## 按常量名取 GameColors 的十六进制色值；例如 "DAMAGE"、"TEXT_PRIMARY"
static func get_game_color(constant_name : String) -> String:
	var value: Variant = GAME_COLORS_SCRIPT.get_script_constant_map().get(constant_name, "")
	if value is Color:
		return (value as Color).to_html()
	return String(value)

#endregion


#region 背包 / 见闻

## 按 content_id 把魂灵放进指定容器（默认仓库第 1 页）
static func add_soul(id : StringName, container : String = "") -> bool:
	if container.is_empty():
		container = CONTAINER_IDS.MAIN_INVENTORY
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % id)
		return false
	return GBIS.add_item(container, soul)


## 按 content_id 把魂灵放进仓库，从第 1 页开始找空位
static func add_soul_to_warehouse(id : StringName) -> bool:
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % id)
		return false
	return Warehouse.add_item(soul)


## 显示商店窗口；找不到窗口返回 false
static func show_shop() -> bool:
	var window := _shop_window()
	if window == null:
		return false
	if not window.visible:
		window.open_window()
	return true


## 按 content_id 往商店放一颗魂灵；不清空已有货物（清空用 clear_container）
static func shop_add_soul(id : StringName) -> bool:
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % id)
		return false
	if not GBIS.shop_names.has(CONTAINER_IDS.SHOP):
		push_warning("TestAPI：商店容器尚未注册，先打开商店窗口")
		return false
	var goods : Array[ItemData] = [soul]
	GBIS.shop_service.load_goods(CONTAINER_IDS.SHOP, goods)
	GBIS.sig_inv_refresh.emit()
	return true


## 模拟左键拿起：从指定容器的格子拿起物品；base_size 只影响拖拽视图大小
static func pick_up_item(container : String, grid_id : Vector2i) -> bool:
	var data := ContainerRepository.instance.get_container(container)
	if data == null:
		return false
	var item := data.find_item_data_by_grid(grid_id)
	if item == null:
		return false
	var origin_grids := data.find_grids_by_item_data(item)
	if origin_grids.is_empty():
		return false
	GBIS.moving_item_service.move_item_by_grid(container, grid_id, grid_id - origin_grids[0], 32)
	return GBIS.has_moving_item()


## 模拟右键取消拿起：优先放回原格；来源未知时返回 false
static func cancel_moving_item() -> bool:
	return GBIS.inventory_service.cancel_moving_item()


## 快速出售指定格子里的物品；商店和该容器都打开才生效
static func quick_sell(container : String, grid_id : Vector2i) -> bool:
	return GBIS.inventory_service.quick_sell(container, grid_id)


## 切换仓库窗口到指定页（0 起）；窗口不存在时返回 false
static func set_warehouse_page(page : int) -> bool:
	var window := _inventory_window()
	if window == null:
		push_warning("TestAPI：找不到仓库窗口")
		return false
	window.set_page(page)
	return true


## 当前仓库页码（0 起）；找不到窗口返回 -1
static func get_warehouse_page() -> int:
	var window := _inventory_window()
	return window.get_page() if window != null else -1


## 装备一颗魂灵。part 为空时按魂灵自身部位；ANY 魂灵依次尝试四个部位。
static func equip_soul(id : StringName, part : String = "") -> bool:
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % id)
		return false
	if part.is_empty():
		if soul.equip_part == "ANY":
			for cell_name in CONTAINER_IDS.soul_cells():
				if GBIS.add_item(cell_name, soul):
					return true
			return false
		part = soul.equip_part
	var cell : String = CONTAINER_IDS.soul_cell_for_part(part)
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


## 真实已解锁的 content_id（不受全解锁开关影响）
static func get_seen_ids(kind : int) -> Array[StringName]:
	return CollectionDB.get_seen_ids(kind)


static func is_seen(kind : int, id : StringName) -> bool:
	return CollectionDB.is_seen(kind, id)


static func get_soul_ids() -> Array[StringName]:
	return CollectionDB.get_soul_ids()


## 魂灵类型（content ID），例如 &"Soul.types.Wolf"
static func get_soul_types(id : StringName) -> Array[StringName]:
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		return []
	return soul.types.duplicate()


## 魂灵标签（见闻筛选 content ID），例如 &"Soul.tags.Small"
static func get_soul_tags(id : StringName) -> Array[StringName]:
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		return []
	return soul.tags.duplicate()


## 所有魂灵的 content_id、技能 ID 和 ability_tag；用于验证技能命名规范化
static func get_skill_tags() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in CollectionDB.get_soul_ids():
		var soul := CollectionDB.get_soul(id)
		if soul == null or soul.skill == null:
			continue
		result.append({
			"content_id": String(id),
			"skill_id": soul.skill.id,
			"ability_tag": "Skill." + soul.skill.id,
		})
	return result


## 魂灵卡面信息：图标路径、占格、名称标签文本；用于验证卡面统一替换
static func get_soul_card_info(id : StringName) -> Dictionary:
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % id)
		return {}
	return {
		"icon": soul.icon.resource_path if soul.icon != null else "",
		"columns": soul.columns,
		"rows": soul.rows,
		"label": soul.item_name,
	}


## 直接伤害的缩放配置：基础伤害、每颗匹配魂灵的加成、匹配类型
static func get_soul_damage_scaling(id : StringName) -> Dictionary:
	var soul := CollectionDB.get_soul(id)
	if soul == null or soul.skill == null:
		return {}
	for effect in soul.skill.effects:
		if effect == null:
			continue
		for execution in effect.executions:
			if execution is SoulDamageExecution:
				var damage := execution as SoulDamageExecution
				return {
					"base_damage": damage.base_damage,
					"bonus_per_matching_soul": damage.bonus_per_matching_soul,
					"matching_soul_types": damage.matching_soul_types.duplicate(),
				}
	return {}


## 魂灵技能的多重触发次数；未知魂灵或没有技能返回 0
static func get_soul_cast_times(id : StringName) -> int:
	var soul := CollectionDB.get_soul(id)
	if soul == null or soul.skill == null:
		return 0
	return maxi(soul.skill.cast_times, 1)


## 魂灵 tooltip 的完整纯文本（第一行是标题，后面是正文）；未知魂灵返回空字符串
static func get_soul_tooltip_text(id : StringName) -> String:
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % id)
		return ""
	return "%s\n%s" % [soul.item_name, SoulTooltip.build(soul)]


## 魂灵 tooltip 的 BBCode 文本；标题不染色，正文里的状态词按战斗日志颜色上色
static func get_soul_tooltip_bbcode(id : StringName) -> String:
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % id)
		return ""
	return "%s\n%s" % [soul.item_name, SoulTooltip.build(soul, true)]


static func get_monster_ids() -> Array[StringName]:
	return CollectionDB.get_monster_ids()


## 标记为稀有的怪物 content_id
static func get_rare_monster_ids() -> Array[StringName]:
	return CollectionDB.get_rare_monster_ids()


static func _inventory_window() -> InventoryWindow:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root : Node = tree.current_scene
	if root == null:
		root = tree.root
	for node in root.find_children("*", "", true, false):
		if node is InventoryWindow:
			return node as InventoryWindow
	return null


static func _shop_window() -> BaseWindow:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root : Node = tree.current_scene
	if root == null:
		root = tree.root
	for node in root.find_children("*", "", true, false):
		if node is BaseWindow and node.name == "ShopWindow":
			return node as BaseWindow
	return null

#endregion


#region 存档

## 立即写档；返回是否成功
static func save_now() -> bool:
	return SaveManager.save_now()


## 从磁盘读档；会清空并重建容器，不要在战斗中调用
static func load_save() -> bool:
	return SaveManager.load_game()


## 只删除磁盘存档，不改变当前内存状态
static func delete_save() -> bool:
	return SaveManager.delete_save()


## 是否存在可读存档
static func has_save() -> bool:
	return SaveManager.has_save()


## 存档文件路径（user://）
static func get_save_path() -> String:
	return SaveManager.get_save_path()


## 当前内存状态的存档快照（不写盘），用于检查序列化结果
static func dump_save() -> Dictionary:
	return SaveManager.collect_save_data()

#endregion


#region Mod

## 已发现 mod 的概况：id / 名称 / 版本 / 启用 / 是否加载 / 内容数量 / 错误
static func get_mod_list() -> Array[Dictionary]:
	return ModLoader.get_mod_list()


## ModLoader 的错误汇总
static func get_mod_errors() -> Array[String]:
	return ModLoader.get_errors()


## 某个 mod 是否为内置 mod（core）
static func is_builtin_mod(mod_id : StringName) -> bool:
	var mod := ModLoader.get_mod(mod_id)
	return mod != null and mod.is_builtin()


## 某个 mod 注册的内容 ID：souls / monsters / cues
static func get_mod_content_ids(mod_id : StringName) -> Dictionary:
	var souls: Array[String] = []
	for entry in ModLoader.get_soul_entries():
		if entry.mod_id == mod_id:
			souls.append(String(entry.content_id))
	var monsters: Array[String] = []
	for entry in ModLoader.get_monster_entries():
		if entry.mod_id == mod_id:
			monsters.append(String(entry.content_id))
	var cues: Array[String] = []
	for entry in ModLoader.get_cue_entries():
		if entry.mod_id == mod_id:
			cues.append(String(entry.content_id))
	return {
		"souls": souls,
		"monsters": monsters,
		"cues": cues,
	}


## 校验 base_mods/core/mod.json 与内容文件是否一致；返回错误列表
static func validate_core_manifest() -> Array[String]:
	return CoreContentValidator.validate()


## 已发现的 mod Cue：tag / mod / path / 是否已注册到 GameplayCueManager
static func get_mod_cues() -> Array[Dictionary]:
	return ModCueRegistrar.get_mod_cues()


## 某个 mod Cue 是否已注册到 GameplayCueManager
static func is_mod_cue_registered(tag : StringName) -> bool:
	return ModCueRegistrar.is_mod_cue_registered(tag)


## 打开 Mod 管理窗口并刷新；找不到窗口返回 false
static func show_mod_window() -> bool:
	var window := _mod_window()
	if window == null:
		return false
	if not window.visible:
		window.popup_centered()
	window.refresh()
	return true


## Mod 管理窗口当前显示的状态：是否可见、mod 数、已加载数、待重启数、错误数、摘要
static func get_mod_window_state() -> Dictionary:
	var window := _mod_window()
	return {} if window == null else window.get_test_state()


## 本次实际加载顺序（只含已启用且未被阻止的 mod）
static func get_mod_load_order() -> Array[StringName]:
	return ModLoader.get_load_order()


## 用户指定的基础加载顺序；包含所有已发现 mod
static func get_mod_order() -> Array[StringName]:
	return ModLoader.get_order_ids()


## 写入基础加载顺序；当前运行期不会重排，重启后生效
static func set_mod_order(ids : Array[StringName]) -> bool:
	return ModLoader.set_mod_order(ids)


## 写启用状态；当前运行期不会卸载/重载，重启后生效
static func set_mod_enabled(mod_id : StringName, enabled : bool) -> bool:
	return ModLoader.set_mod_enabled(mod_id, enabled)


## 当前存档里因 mod 缺失/容器满而保留的原始记录
static func get_orphaned_records() -> Array[Dictionary]:
	return SaveManager.get_orphaned_records()

#endregion


#region 窗口

## 设置窗口置顶；window_name 为节点名（CharacterWindow 等），MainWindow 表示主窗口
static func set_window_pinned(window_name : String, pinned : bool) -> bool:
	if window_name == "MainWindow":
		var main := _main_window()
		if main == null:
			return false
		main.always_on_top = pinned
		WindowPinSettings.save_pin(window_name, pinned)
		_sync_main_pin_button(pinned)
		return true
	var window := _window_by_name(window_name)
	if window is BaseWindow:
		(window as BaseWindow).set_pinned(pinned)
		return true
	return false


## 查询窗口置顶状态
static func is_window_pinned(window_name : String) -> bool:
	if window_name == "MainWindow":
		var main := _main_window()
		return main != null and main.always_on_top
	var window := _window_by_name(window_name)
	return window is BaseWindow and (window as BaseWindow).is_pinned()


## 所有普通窗口的置顶状态：{节点名: bool}，含 MainWindow
static func get_window_pin_states() -> Dictionary:
	var result := {}
	var main := _main_window()
	if main != null:
		result["MainWindow"] = main.always_on_top
	for window in _window_nodes():
		if window is BaseWindow:
			result[String(window.name)] = (window as BaseWindow).is_pinned()
	return result


static func _main_window() -> Window:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root as Window


static func _window_nodes() -> Array[Window]:
	var result: Array[Window] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return result
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	for node in root.find_children("*", "", true, false):
		if node is Window:
			result.append(node as Window)
	return result


static func _window_by_name(window_name : String) -> Window:
	for window in _window_nodes():
		if String(window.name) == window_name:
			return window
	return null


static func _sync_main_pin_button(pinned : bool) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var status := tree.root.find_child("StatusBarContainer", true, false)
	if status == null:
		return
	var button := status.get_node_or_null("Button2")
	if button is Button:
		(button as Button).set_pressed_no_signal(pinned)

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
	# 真实冻结会广播 FREEZE_APPLIED；测试接口保持一致，便于验证冻结触发器
	unit.notify_freeze_applied(unit)
	return true


## 在战斗中的单位身上播放爪痕特效；direction：1 = 左→右，-1 = 右→左
static func play_claw_cue(target : String = "enemy", direction : int = 1) -> bool:
	var unit := _find_unit(target)
	if unit == null or unit.asc == null:
		return false
	unit.asc.execute_cue(&"Cue.Combat.ClawSlash", {"direction": 1.0 if direction >= 0 else -1.0})
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


static func _mod_window() -> ModWindow:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root : Node = tree.current_scene
	if root == null:
		root = tree.root
	for node in root.find_children("*", "", true, false):
		if node is ModWindow:
			return node as ModWindow
	return null

#endregion
