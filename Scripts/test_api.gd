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
## 色板目录：分组、别名、校验
const GAME_COLOR_CATALOG : GDScript = preload("res://Scripts/game_color_catalog.gd")


#region 颜色

## 按常量名取 GameColors 的十六进制色值；例如 "DAMAGE"、"TEXT_PRIMARY"
static func get_game_color(constant_name : String) -> String:
	var value: Variant = GAME_COLORS_SCRIPT.get_script_constant_map().get(constant_name, "")
	if value is Color:
		return (value as Color).to_html()
	return String(value)


## 色板目录：groups / aliases / ungrouped / status / terminal
static func get_color_catalog() -> Dictionary:
	return {
		"groups": GAME_COLOR_CATALOG.groups(),
		"aliases": GAME_COLOR_CATALOG.aliases(),
		"ungrouped": GAME_COLOR_CATALOG.ungrouped(),
		"status": GAME_COLOR_CATALOG.status_entries(),
		"terminal": GAME_COLOR_CATALOG.terminal_palette(),
	}


## 色板分组校验：空数组表示所有 GameColors 颜色常量都已归类
static func validate_color_groups() -> Array[String]:
	return GAME_COLOR_CATALOG.validate()

#endregion


#region 终端

## 向当前场景里的 TerminalView 写一行；预览场景/终端窗口用，找不到返回 false
static func terminal_write_line(text : String) -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.write_line(text)
	return true


## 按 ANSI 转义序列往当前 TerminalView 写文本；找不到返回 false
static func terminal_write_ansi(text : String) -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.write_ansi(text)
	return true


## 显示用：整屏替换为多行纯文本；找不到返回 false
static func terminal_set_content(text : String) -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.set_content(PackedStringArray(text.split("\n")))
	return true


## 显示用：整屏替换为多行 ANSI 文本；找不到返回 false
static func terminal_set_ansi_content(text : String) -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.set_ansi_content(PackedStringArray(text.split("\n")))
	return true


## 往历史翻 lines 行；正值向上，负值向下
static func terminal_scroll(lines : int) -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.scroll_by(lines)
	return true


## 回到实时屏幕并恢复自动滚底
static func terminal_scroll_to_bottom() -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.scroll_to_bottom()
	return true


## 清空当前 TerminalView；找不到返回 false
static func terminal_clear() -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.clear()
	return true


## 开关当前 TerminalView 的调试网格；找不到返回 false
static func terminal_set_grid(enabled: bool) -> bool:
	var view := _terminal_view()
	if view == null:
		return false
	view.set_debug_grid(enabled)
	return true


## 当前 TerminalView 的网格/回看信息；找不到返回 {}
static func terminal_snapshot() -> Dictionary:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return {}
	return {
		"cols": view.buffer.cols,
		"rows": view.buffer.rows,
		"cell": view.get_cell_size(),
		"cursor": Vector2i(view.buffer.cursor_col, view.buffer.cursor_row),
		"history": view.get_scrollback_count(),
		"view_offset": view.view_offset,
		"auto_scroll": view.auto_scroll,
		"spans": view.get_span_rects(),
	}


## 当前浮动 Tooltip 的内容终端状态（标题 span + 正文）；未显示返回 {}
static func tooltip_snapshot() -> Dictionary:
	var tip := TooltipWindow.instance
	if not is_instance_valid(tip) or not tip.visible:
		return {}
	for node in tip.find_children("*", "", true, false):
		if node is TerminalView:
			var view := node as TerminalView
			if view.buffer == null or not view.visible:
				return {}
			return {
				"grid": view.get_grid_size(),
				"debug_grid": view.debug_grid,
				"body_visible": view.visible,
				"tooltip_size": tip.size,
				"spans": view.get_span_rects(),
			}
	return {}


## 打开终端窗口；找不到窗口返回 false
static func show_terminal() -> bool:
	var window := _terminal_window()
	if window == null:
		return false
	if not window.visible:
		window.open_window()
	return true


## 终端窗口当前是否可见；找不到窗口返回 false
static func is_terminal_open() -> bool:
	var window := _terminal_window()
	return window != null and window.visible


## 在终端里显示魂灵 tooltip（标题 + ANSI 正文）；equipped 时用动态预览值。
## grid 默认打开调试网格；找不到终端或魂灵返回 false。
static func terminal_show_soul_tooltip(
	id : StringName, equipped : bool = false, grid : bool = true
) -> bool:
	var text := get_equipped_soul_tooltip_ansi(id) if equipped else get_soul_tooltip_ansi(id)
	if text.is_empty():
		return false
	return _terminal_show_tooltip(text, grid)


## 在终端里显示魂器模板 tooltip（标题 + ANSI 正文）；grid 默认打开调试网格
static func terminal_show_vessel_tooltip(id : StringName, grid : bool = true) -> bool:
	var text := get_vessel_tooltip_ansi(id)
	if text.is_empty():
		return false
	return _terminal_show_tooltip(text, grid)


## 在终端里显示魂器网格里第 slot 个魂器的 tooltip；grid 默认打开调试网格
static func terminal_show_equipped_vessel_tooltip(
	slot : int = 0, grid : bool = true
) -> bool:
	var text := get_equipped_vessel_tooltip_ansi(slot)
	if text.is_empty():
		return false
	return _terminal_show_tooltip(text, grid)

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
	return GBIS.moving_item_service.pick_from_grid(container, grid_id, grid_id - origin_grids[0], 32)


## 模拟右键取消拿起：优先放回原格；来源未知时返回 false
static func cancel_moving_item() -> bool:
	return GBIS.moving_item_service.cancel()


## 把正在拖拽的物品放到指定格子；grid_id 是鼠标点击格，物品左上角 = grid_id - 抓取偏移
static func drop_moving_item(container : String, grid_id : Vector2i) -> bool:
	return GBIS.moving_item_service.drop_on_grid(container, grid_id)


## 在商店出售正在拖拽的物品；返回是否成功
static func sell_moving_item() -> bool:
	return GBIS.moving_item_service.sell_dragged()


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


## 按 content_id 把魂器放进指定容器（默认仓库第 1 页）
static func add_vessel(id : StringName, container : String = "") -> bool:
	if container.is_empty():
		container = CONTAINER_IDS.MAIN_INVENTORY
	var vessel := CollectionDB.get_vessel(id)
	if vessel == null:
		push_warning("TestAPI：魂器不存在 %s" % id)
		return false
	return GBIS.add_item(container, vessel)


## 把战斗魂器装进角色魂器网格；网格放不下时返回 false
static func equip_vessel(id : StringName) -> bool:
	var vessel := CollectionDB.get_vessel(id)
	if vessel == null:
		push_warning("TestAPI：魂器不存在 %s" % id)
		return false
	return GBIS.add_item(CONTAINER_IDS.VESSEL_GRID, vessel)


## 往魂器网格里第 vessel_slot 个魂器中放一颗魂灵；魂器内部容器只收 SOUL
static func vessel_add_soul(soul_id : StringName, vessel_slot : int = 0) -> bool:
	var soul := CollectionDB.get_soul(soul_id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % soul_id)
		return false
	var vessel := _equipped_vessel(vessel_slot)
	if vessel == null:
		push_warning("TestAPI：魂器网格第 %d 个魂器不存在" % vessel_slot)
		return false
	var contents := vessel.ensure_contents()
	var item := soul.make_instance()
	var grids := contents.add_item(item)
	if grids.is_empty():
		return false
	GBIS.sig_inv_item_added.emit(contents.container_name, item, grids)
	return true


## 魂器网格里第 vessel_slot 个魂器中的魂灵名；没有这个魂器时返回空数组
static func get_vessel_contents(vessel_slot : int = 0) -> Array[String]:
	var names : Array[String] = []
	var vessel := _equipped_vessel(vessel_slot)
	if vessel == null:
		return names
	for item in vessel.ensure_contents().items:
		if item != null:
			names.append(item.item_name)
	return names


## 已加载的魂器 content_id
static func get_vessel_ids() -> Array[StringName]:
	return CollectionDB.get_vessel_ids()


## 魂器网格里第 vessel_slot 个魂器的 tooltip 正文（含内部魂灵网格）
static func get_equipped_vessel_tooltip_text(vessel_slot : int = 0) -> String:
	var vessel := _equipped_vessel(vessel_slot)
	if vessel == null:
		return ""
	return "%s\n%s" % [vessel.item_name, VesselTooltip.build(vessel)]


## 魂器网格里第 vessel_slot 个魂器的 tooltip 正文（BBCode）
static func get_equipped_vessel_tooltip_bbcode(vessel_slot : int = 0) -> String:
	var vessel := _equipped_vessel(vessel_slot)
	if vessel == null:
		return ""
	return "%s\n%s" % [
		vessel.item_name,
		VesselTooltip.build(vessel, TooltipText.Format.BBCODE),
	]


## 魂器网格里第 vessel_slot 个魂器的 tooltip 正文（终端 ANSI）
static func get_equipped_vessel_tooltip_ansi(vessel_slot : int = 0) -> String:
	var vessel := _equipped_vessel(vessel_slot)
	if vessel == null:
		return ""
	return "%s\n%s" % [
		TooltipText.title_ansi(vessel.item_name),
		VesselTooltip.build(vessel, TooltipText.Format.ANSI),
	]


static func _equipped_vessel(vessel_slot : int) -> SoulVesselData:
	var container := ContainerRepository.instance.get_container(CONTAINER_IDS.VESSEL_GRID)
	if container == null:
		return null
	var vessels := SoulVesselData.combat_vessels_in(container)
	if vessel_slot < 0 or vessel_slot >= vessels.size():
		return null
	return vessels[vessel_slot]


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


## 校验 ContainerIds 里的容器是否都已注册；在主场景运行后调用
static func validate_container_ids() -> Array[String]:
	var errors: Array[String] = []
	var expected: Array[String] = [
		CONTAINER_IDS.MAIN_INVENTORY,
		CONTAINER_IDS.SHOP,
		CONTAINER_IDS.VESSEL_GRID,
	]
	for container_name in expected:
		if ContainerRepository.instance.get_container(container_name) == null:
			errors.append("容器未注册：%s" % container_name)
	return errors


## 临时切换见闻“全部已解锁”；不改存档
static func set_unlock_all(enabled : bool) -> void:
	CollectionDB.set_unlock_all_for_testing(enabled)


## 永久解锁全部见闻并触发写档；返回是否新增了记录
static func unlock_all_collection() -> bool:
	return CollectionDB.unlock_all()


## 真实已解锁的 content_id（不受全解锁开关影响）
static func get_seen_ids(kind : int) -> Array[StringName]:
	return CollectionDB.get_seen_ids(kind)


static func is_seen(kind : int, id : StringName) -> bool:
	return CollectionDB.is_seen(kind, id)


static func get_soul_ids() -> Array[StringName]:
	return CollectionDB.get_soul_ids()


## 魂灵类型（GAS 标签），例如 &"Soul.types.Wolf"
static func get_soul_types(id : StringName) -> Array[StringName]:
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		return []
	return soul.types.duplicate()


## 魂灵标签（GAS 标签，见闻筛选用），例如 &"Soul.tags.Small"
static func get_soul_tags(id : StringName) -> Array[StringName]:
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		return []
	return soul.tags.duplicate()


## 魂灵尺寸标签，例如 &"Soul.tags.Medium"
static func get_soul_size_tag(id : StringName) -> StringName:
	var soul := CollectionDB.get_soul(id)
	return soul.size_tag() if soul != null else &""


## 魂器名 + tooltip 正文
static func get_vessel_tooltip_text(id : StringName) -> String:
	var vessel := CollectionDB.get_vessel(id)
	if vessel == null:
		push_warning("TestAPI：魂器不存在 %s" % id)
		return ""
	return "%s\n%s" % [vessel.item_name, VesselTooltip.build(vessel)]


## 魂器 tooltip 正文（BBCode）
static func get_vessel_tooltip_bbcode(id : StringName) -> String:
	var vessel := CollectionDB.get_vessel(id)
	if vessel == null:
		push_warning("TestAPI：魂器不存在 %s" % id)
		return ""
	return "%s\n%s" % [
		vessel.item_name,
		VesselTooltip.build(vessel, TooltipText.Format.BBCODE),
	]


## 魂器 tooltip 正文（终端 ANSI）
static func get_vessel_tooltip_ansi(id : StringName) -> String:
	var vessel := CollectionDB.get_vessel(id)
	if vessel == null:
		push_warning("TestAPI：魂器不存在 %s" % id)
		return ""
	return "%s\n%s" % [
		TooltipText.title_ansi(vessel.item_name),
		VesselTooltip.build(vessel, TooltipText.Format.ANSI),
	]


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
	var damage := SoulDamagePreview.find_damage_execution(soul.skill)
	if damage == null:
		return {}
	return {
		"base_damage": damage.base_damage,
		"bonus_per_matching_soul": damage.bonus_per_matching_soul,
		"matching_soul_types": damage.matching_soul_types.duplicate(),
	}


## 已装备魂灵的伤害预览；战斗中优先运行期值，否则按当前魂器网格静态预览。
## 未装备返回 {}。静态预览只汇总被动魂灵 modifiers 里的 STATIC 数值。
static func get_equipped_soul_damage_preview(id : StringName) -> Dictionary:
	var context := _equipped_soul_context(id)
	if context.is_empty():
		return {}
	var preview := context["preview"] as SoulDamagePreview
	return {
		"base_damage": preview.base_damage,
		"bonus_per_matching_soul": preview.bonus_per_matching_soul,
		"matching_soul_types": preview.matching_soul_types.duplicate(),
		"matching_soul_count": preview.matching_soul_count,
		"player_damage_bonus": preview.player_damage_bonus,
		"vessel_damage_bonus": preview.vessel_damage_bonus,
		"is_dynamic": preview.is_dynamic,
		"has_runtime": preview.has_runtime,
		"total": preview.total(),
	}


## 技能步骤概况：类型、domain、目标规则、效果数量；用于验证多步骤技能
static func get_soul_steps(id : StringName) -> Array[Dictionary]:
	var soul := CollectionDB.get_soul(id)
	if soul == null or soul.skill == null:
		return []
	var result: Array[Dictionary] = []
	for index in soul.skill.steps.size():
		var step := soul.skill.steps[index]
		var info := {"index": index, "type": "unknown", "domain": ""}
		var rule_path := ""
		if step is UnitSkillStep:
			var unit_step := step as UnitSkillStep
			if unit_step.target_rule != null and unit_step.target_rule.get_script() != null:
				rule_path = unit_step.target_rule.get_script().resource_path
			info["type"] = "unit"
			info["domain"] = "UNIT" if unit_step.target_rule != null else ""
			info["target_rule"] = rule_path
			info["effect_count"] = unit_step.effects.size()
			info["projectile"] = unit_step.projectile_scene != null
			info["hit_cue_tag"] = String(unit_step.hit_cue_tag)
			info["status_magnitude"] = unit_step.status_magnitude
		elif step is SoulSkillStep:
			var soul_step := step as SoulSkillStep
			if soul_step.target_rule != null and soul_step.target_rule.get_script() != null:
				rule_path = soul_step.target_rule.get_script().resource_path
			info["type"] = "soul"
			info["domain"] = "SOUL" if soul_step.target_rule != null else ""
			info["target_rule"] = rule_path
			info["haste_duration"] = soul_step.haste_duration
			info["slow_duration"] = soul_step.slow_duration
			info["freeze_duration"] = soul_step.freeze_duration
			info["charge_duration"] = soul_step.charge_duration
		result.append(info)
	return result


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
	return "%s\n%s" % [soul.item_name, SoulTooltip.build(soul, TooltipText.Format.BBCODE)]


## 魂灵 tooltip 的 ANSI 文本；标题粗体，可直接喂给 terminal_set_ansi_content()
static func get_soul_tooltip_ansi(id : StringName) -> String:
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % id)
		return ""
	return "%s\n%s" % [
		TooltipText.title_ansi(soul.item_name),
		SoulTooltip.build(soul, TooltipText.Format.ANSI),
	]


## 已装备魂灵的动态 tooltip 纯文本；未装备时回退静态 tooltip
## 战斗中优先运行期值，否则按当前魂器网格做“装上后”静态预览。
static func get_equipped_soul_tooltip_text(id : StringName) -> String:
	var context := _equipped_soul_context(id)
	if context.is_empty():
		return get_soul_tooltip_text(id)
	var soul := context["soul"] as SoulData
	var preview := context["preview"] as SoulDamagePreview
	return "%s\n%s" % [
		soul.item_name,
		SoulTooltip.build(soul, TooltipText.Format.PLAIN, preview),
	]


## 已装备魂灵的动态 tooltip BBCode；未装备时回退静态 tooltip
static func get_equipped_soul_tooltip_bbcode(id : StringName) -> String:
	var context := _equipped_soul_context(id)
	if context.is_empty():
		return get_soul_tooltip_bbcode(id)
	var soul := context["soul"] as SoulData
	var preview := context["preview"] as SoulDamagePreview
	return "%s\n%s" % [
		soul.item_name,
		SoulTooltip.build(soul, TooltipText.Format.BBCODE, preview),
	]


## 已装备魂灵的动态 tooltip ANSI；未装备时回退静态 tooltip
static func get_equipped_soul_tooltip_ansi(id : StringName) -> String:
	var context := _equipped_soul_context(id)
	if context.is_empty():
		return get_soul_tooltip_ansi(id)
	var soul := context["soul"] as SoulData
	var preview := context["preview"] as SoulDamagePreview
	return "%s\n%s" % [
		TooltipText.title_ansi(soul.item_name),
		SoulTooltip.build(soul, TooltipText.Format.ANSI, preview),
	]


static func get_monster_ids() -> Array[StringName]:
	return CollectionDB.get_monster_ids()


## 怪物的可选刷新距离（格）
static func get_monster_spawn_distances(id : StringName) -> Array[int]:
	var monster := CollectionDB.get_monster(id)
	if monster == null:
		push_warning("TestAPI：怪物不存在 %s" % id)
		return []
	return monster.spawn_distances.duplicate()


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

## 立即写当前槽；没有活动槽时返回 false
static func save_now() -> bool:
	return SaveManager.save_now()


## 完整流程读档：更新 GameFlow、锁定面和立方体朝向；空槽返回 false
static func load_save_slot(slot: int) -> bool:
	return GameFlow.request_load_slot(slot)


## 直接读档，不改变 GameFlow 状态；用于存档格式/迁移测试
static func load_save_slot_raw(slot: int) -> bool:
	return SaveManager.load_slot(slot)


## 新游戏：走 01 面新游戏 → 04 面选角 → 02 面完整流程
static func new_game(character_id: StringName = &"small_coal_lamp") -> bool:
	GameFlow.request_new_game()
	if GameFlow.get_state() != GameFlow.State.CHARACTER_SELECT:
		return false
	return GameFlow.create_new_game(character_id)


## 直接删除指定槽的磁盘存档（绕过 UI 二次确认）；删活动槽会断开活动槽
static func delete_save_slot(slot: int) -> bool:
	return SaveManager.delete_slot(slot)


## 是否存在任意可读存档
static func has_save() -> bool:
	return SaveManager.has_any_save()


## 六个槽的视图数据：slot / occupied / character_name / active
static func get_save_slots() -> Array[Dictionary]:
	return GameFlow.get_slot_summaries()


## 当前活动槽；没有活动槽返回 -1
static func get_active_slot() -> int:
	return SaveManager.get_active_slot()


## 会话状态快照：state / active_slot / character_id / character_name
static func get_game_flow_state() -> Dictionary:
	return GameFlow.get_state_snapshot()


## 指定槽的存档文件路径（user://）
static func get_save_path(slot: int) -> String:
	return SaveManager.get_save_path(slot)


## 存档状态：ready / read_only / missing_containers / active_slot
static func get_save_status() -> Dictionary:
	return SaveManager.get_save_status()


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


## 不阻止加载的 mod 诊断（未知 manifest 字段、技能 ID 冲突等）
static func get_mod_warnings() -> Array[String]:
	return ModLoader.get_warnings()


## 某个 mod 是否为内置 mod（core）
static func is_builtin_mod(mod_id : StringName) -> bool:
	var mod := ModLoader.get_mod(mod_id)
	return mod != null and mod.is_builtin()


## 某个 mod 注册的内容 ID：souls / monsters / vessels / cues
static func get_mod_content_ids(mod_id : StringName) -> Dictionary:
	var souls: Array[String] = []
	for entry in ModLoader.get_soul_entries():
		if entry.mod_id == mod_id:
			souls.append(String(entry.content_id))
	var monsters: Array[String] = []
	for entry in ModLoader.get_monster_entries():
		if entry.mod_id == mod_id:
			monsters.append(String(entry.content_id))
	var vessels: Array[String] = []
	for entry in ModLoader.get_vessel_entries():
		if entry.mod_id == mod_id:
			vessels.append(String(entry.content_id))
	var cues: Array[String] = []
	for entry in ModLoader.get_cue_entries():
		if entry.mod_id == mod_id:
			cues.append(String(entry.content_id))
	return {
		"souls": souls,
		"monsters": monsters,
		"vessels": vessels,
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
		window.open_window()
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

## 设置主窗口置顶；单窗口模式下子面板没有原生置顶。
static func set_window_pinned(window_name : String, pinned : bool) -> bool:
	if window_name != "MainWindow":
		return false
	var main := _main_window()
	if main == null:
		return false
	main.always_on_top = pinned
	WindowPinSettings.save_pin(WindowPinSettings.MAIN_WINDOW_ID, pinned)
	_sync_main_pin_button(pinned)
	return true


## 查询主窗口置顶状态；子面板固定返回 false。
static func is_window_pinned(window_name : String) -> bool:
	if window_name != "MainWindow":
		return false
	var main := _main_window()
	return main != null and main.always_on_top


## 主窗口置顶状态：{"MainWindow": bool}
static func get_window_pin_states() -> Dictionary:
	var result := {}
	var main := _main_window()
	if main != null:
		result["MainWindow"] = main.always_on_top
	return result


## 立方体中心的屏幕坐标（主视口像素）；找不到返回 (-1, -1)
static func get_cube_screen_position() -> Vector2:
	var placement := _cube_placement()
	return placement.get_screen_center() if placement != null else Vector2(-1, -1)


## 把立方体移到指定屏幕坐标并持久化到 [cube]；找不到返回 false
static func set_cube_screen_position(target_position : Vector2) -> bool:
	var placement := _cube_placement()
	if placement == null:
		return false
	placement.set_screen_center(target_position)
	placement.save_position()
	return true


## 当前激活面板的节点名；没有返回 ""
static func get_active_panel_name() -> String:
	var manager := PanelManager.instance
	if manager == null:
		return ""
	var panel := manager.get_active()
	return String(panel.name) if panel != null else ""


## 所有可见 BaseWindow 面板的全局矩形
static func get_visible_panel_rects() -> Array[Rect2]:
	var result : Array[Rect2] = []
	var manager := PanelManager.instance
	if manager != null:
		result = manager.get_visible_panel_rects()
	return result


static func _main_window() -> Window:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root as Window


static func _cube_placement() -> CubePlacement:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root : Node = tree.current_scene
	if root == null:
		root = tree.root
	for node in root.find_children("*", "", true, false):
		if node is CubePlacement:
			return node as CubePlacement
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


#region 立方体外壳

## 透明覆盖层点击穿透总开关；找不到模块返回 false
static func set_cube_passthrough_enabled(enabled : bool) -> bool:
	var module := WindowPassthrough.instance
	if module == null:
		return false
	module.enabled = enabled
	return true


## 透明覆盖层点击穿透是否开启
static func is_cube_passthrough_enabled() -> bool:
	var module := WindowPassthrough.instance
	return module != null and module.enabled


## 穿透状态：enabled / locked / rects / polygon_points
static func get_cube_passthrough_state() -> Dictionary:
	var module := WindowPassthrough.instance
	if module == null:
		return {}
	return {
		"enabled": module.enabled,
		"locked": module.is_locked(),
		"rects": module.get_hit_rects().size(),
		"polygon_points": module.get_polygon_points().size(),
	}


## 立方体状态：缩放、屏幕位置、朝向、正对面、面 02 的 UI 视口与穿透
static func get_cube_state() -> Dictionary:
	if _cube_rig() == null:
		return {}
	var pivot := _cube_orientation()
	var camera := _cube_camera()
	var ui_face_viewport := _ui_face_viewport()
	return {
		"cube_scale": _cube_scale(),
		"screen_center": get_cube_screen_position(),
		"view_layer": _cube_view_layer(),
		"orientation": pivot.quaternion if pivot != null else Quaternion.IDENTITY,
		"front_face_index": _front_face_index(camera) if camera != null else -1,
		"ui_face_index": 1,
		"ui_face_viewport_size": (
				ui_face_viewport.size if ui_face_viewport != null else Vector2i.ZERO
		),
		"passthrough": get_cube_passthrough_state(),
	}


## 立方体层级：CubeView 压住 GameUI；HUD Toast 提到立方体之上，Tooltip 与拖拽幽灵仍在最上
static func get_cube_layering_state() -> Dictionary:
	var surface := CubeInputSurface.instance
	if surface == null:
		return {}
	var cube_layer := _cube_view_layer()
	if cube_layer < 0:
		return {}

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {}
	var cube_view := tree.root.find_child("CubeView", true, false) as CanvasLayer
	var game_ui := tree.root.find_child("GameUI", true, false) as CanvasLayer
	var hud := tree.root.find_child("HUD", true, false) as CanvasLayer
	var tooltip := tree.root.find_child("TooltipLayer", true, false) as CanvasLayer
	var drag := tree.root.find_child("DragLayer", true, false) as CanvasLayer
	var rig := _cube_rig()
	var viewport := rig.get_viewport() if rig != null else null
	return {
		"cube_layer": cube_layer,
		"game_ui_layer": game_ui.layer if game_ui != null else -1,
		"hud_layer": hud.layer if hud != null else -1,
		"tooltip_layer": tooltip.layer if tooltip != null else -1,
		"drag_layer": drag.layer if drag != null else -1,
		"above_game_ui": game_ui != null and cube_layer > game_ui.layer,
		"above_hud": hud != null and cube_layer > hud.layer,
		"hud_above_cube": (
			hud != null and cube_view != null
			and (
				hud.layer > cube_view.layer
				or (
					hud.layer == cube_view.layer
					and hud.get_index() > cube_view.get_index()
				)
			)
		),
		"below_tooltip": tooltip != null and cube_layer < tooltip.layer,
		"below_drag_ghost": drag != null and cube_layer < drag.layer,
		"input_ready": surface.is_ready(),
		"hull_points": surface.get_hull_points().size(),
		"viewport_size": (
				Vector2i(viewport.get_visible_rect().size)
				if viewport != null
				else Vector2i.ZERO
		),
	}


## 立即把指定面转到正对相机；测试用
static func set_cube_face_front(face_index : int) -> bool:
	var orientation := _cube_orientation()
	if orientation == null:
		return false
	return orientation.snap_face_to_camera(face_index)


## 面内容类型：face_ui / pet_panel / save_slots / character_select / unknown
static func get_cube_face_content(face_index : int) -> String:
	var content := _cube_face_content(face_index)
	return String(content.content_id()) if content != null else "unknown"


## 面是否锁定；02 只在游戏中解锁，04 只在角色选择时解锁
static func get_cube_face_lock_state(face_index : int) -> bool:
	return GameFlow.get_face_lock_state(face_index)


## 触发普通面的识别按钮，走与点击一致的信号链；非 FaceUI 面返回 false
static func click_cube_face_button(face_index : int) -> bool:
	var face_ui := _cube_face_content(face_index) as FaceUI
	if face_ui == null:
		return false
	face_ui.identify_requested.emit()
	return true


## 点击 01 面「新游戏」按钮
static func click_cube_new_game() -> bool:
	var content := _cube_face_content(0) as SaveSlotsContent
	if content == null:
		return false
	content.activate_new_game()
	return true


## 点击 01 面指定存档位（0..5）
static func click_cube_save_slot(slot: int) -> bool:
	var content := _cube_face_content(0) as SaveSlotsContent
	if content == null:
		return false
	return content.activate_slot(slot)


## 点击 01 面指定存档位的删除按钮（0..5）；两段式，调用两次才真正删除
static func click_cube_delete_save_slot(slot: int) -> bool:
	var content := _cube_face_content(0) as SaveSlotsContent
	if content == null:
		return false
	return content.activate_delete(slot)


## 点击 04 面指定角色
static func click_cube_character(character_id: StringName) -> bool:
	var content := _cube_face_content(3) as CharacterSelectContent
	if content == null:
		return false
	return content.activate_character(character_id)


## 触发面 02 主菜单按钮（按 panel_id，如 "inventory"），走完整信号链
static func click_cube_pet_button(panel_id : StringName) -> bool:
	var viewport := _ui_face_viewport()
	if viewport == null:
		return false
	var panel := viewport.find_child("PetPanel", true, false) as PetPanel
	if panel == null:
		return false
	var grid := panel.get_node_or_null("GridContainer")
	if grid == null:
		return false
	for child in grid.get_children():
		var button := child as Button
		if button == null:
			continue
		if StringName(button.get_meta(&"panel_id", "")) == panel_id:
			button.pressed.emit()
			return true
	return false


static func _cube_rig() -> CubeRig:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root : Node = tree.current_scene
	if root == null:
		root = tree.root
	for node in root.find_children("*", "", true, false):
		if node is CubeRig:
			return node as CubeRig
	return null


static func _cube_orientation() -> CubeOrientation:
	var rig := _cube_rig()
	if rig == null:
		return null
	return rig.get_node_or_null("OrientationPivot") as CubeOrientation


static func _cube_face(face_index : int) -> Face3D:
	var orientation := _cube_orientation()
	if orientation == null:
		return null
	for child in orientation.get_children():
		if child is Face3D and (child as Face3D).face_index == face_index:
			return child as Face3D
	return null


static func _cube_face_viewport(face_index : int) -> SubViewport:
	var face := _cube_face(face_index)
	if face == null:
		return null
	return face.get_node_or_null("Viewport") as SubViewport


static func _cube_face_content(face_index : int) -> FaceContent:
	var viewport := _cube_face_viewport(face_index)
	if viewport == null:
		return null
	for child in viewport.get_children():
		if child is FaceContent:
			return child as FaceContent
	return null


static func _ui_face_viewport() -> SubViewport:
	return _cube_face_viewport(1)


static func _cube_scale() -> float:
	var rig := _cube_rig()
	if rig == null:
		return 0.0
	var cube := rig.get_parent() as Node3D
	if cube == null:
		return 0.0
	return cube.global_transform.basis.get_scale().x


static func _cube_camera() -> Camera3D:
	var rig := _cube_rig()
	if rig == null:
		return null
	return rig.get_viewport().get_camera_3d()


static func _cube_view_layer() -> int:
	var surface := CubeInputSurface.instance
	if surface == null:
		return -1
	var layer := surface.get_parent() as CanvasLayer
	return layer.layer if layer != null else -1


static func _front_face_index(camera : Camera3D) -> int:
	var orientation := _cube_orientation()
	if orientation == null:
		return -1
	var to_camera := (camera.global_position - orientation.global_position).normalized()
	var best_index := -1
	var best_alignment := -INF
	for child in orientation.get_children():
		if not child is Face3D:
			continue
		var face := child as Face3D
		var alignment := face.global_basis.z.normalized().dot(to_camera)
		if alignment > best_alignment:
			best_alignment = alignment
			best_index = face.face_index
	return best_index

#endregion


#region 战斗

## 显示战斗窗口并开战；monster_id 非空时首只必刷该怪
static func start_battle(monster_id : StringName = &"") -> bool:
	var window := _battle_window()
	if window == null:
		push_warning("TestAPI：找不到 BattleWindow")
		return false
	if not window.visible:
		window.open_window()
	window.start_battle(monster_id)
	return true


## 结束当前战斗
static func stop_battle() -> void:
	var window := _battle_window()
	if window != null:
		window.stop_battle()


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


## 对战斗中的单位施加生命再生（用于验证剧毒/生命再生相减）
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


## 模拟某个已装备魂灵被“使用”一次（不动冷却），用于确定性地测 SoulUsed 触发器
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
	return InfoWindow.instance.get_log_text()


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


## 按内容 id 找玩家当前装备的魂灵运行期实例；同一 id 有多颗时取第一颗
static func _player_runtime_for(id : StringName) -> SoulRuntime:
	for runtime in SoulRuntimeDB.player_runtimes():
		if runtime.soul != null and runtime.soul.content_id == id:
			return runtime
	return null


## 已装备魂灵的展示上下文：soul + preview；未装备返回 {}
## 战斗中优先运行期值，否则按当前魂器网格做“装上后”静态预览。
static func _equipped_soul_context(id : StringName) -> Dictionary:
	var runtime := _player_runtime_for(id)
	if runtime != null and runtime.soul != null:
		return {
			"soul": runtime.soul,
			"preview": SoulDamagePreview.for_soul(runtime.soul, runtime),
		}
	var entry := _equipped_soul_entry(id)
	if entry.is_empty():
		return {}
	var soul := entry["soul"] as SoulData
	var vessel := entry["vessel"] as SoulVesselData
	var grid := ContainerRepository.instance.get_container(CONTAINER_IDS.VESSEL_GRID)
	return {
		"soul": soul,
		"preview": SoulDamagePreview.preview_for(
			soul, vessel, SoulVesselData.combat_souls_in(grid)
		),
	}


## 在角色魂器网格里按内容 id 找魂灵实例和所在魂器；找不到返回 {}
static func _equipped_soul_entry(id : StringName) -> Dictionary:
	var grid := ContainerRepository.instance.get_container(CONTAINER_IDS.VESSEL_GRID)
	if grid == null:
		return {}
	for vessel in SoulVesselData.combat_vessels_in(grid):
		for item in vessel.ensure_contents().items:
			if item is SoulData and (item as SoulData).content_id == id:
				return {"soul": item as SoulData, "vessel": vessel}
	return {}


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


## 把标题 + ANSI 正文写进当前 TerminalView；grid 控制调试网格开关
static func _terminal_show_tooltip(text : String, grid : bool) -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.set_debug_grid(grid)
	view.set_ansi_content(PackedStringArray(text.split("\n")))
	show_terminal()
	return true


static func _terminal_view() -> TerminalView:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root : Node = tree.current_scene
	if root == null:
		root = tree.root
	for node in root.find_children("*", "", true, false):
		if node is TerminalView:
			return node as TerminalView
	return null


static func _terminal_window() -> TerminalWindow:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root : Node = tree.current_scene
	if root == null:
		root = tree.root
	for node in root.find_children("*", "", true, false):
		if node is TerminalWindow:
			return node as TerminalWindow
	return null

#endregion
