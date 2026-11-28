extends RefCounted

const COMMON: GDScript = preload("res://scripts/test_api/common.gd")

const CONTAINER_IDS: GDScript = preload("res://scripts/container_ids.gd")

static func add_soul(id : StringName, container : String = "") -> bool:
	var soul := ModLoader.get_soul(id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % id)
		return false
	if container.is_empty():
		return Warehouse.add_item(soul)
	if not has_container(container):
		push_warning("TestAPI：容器不存在 %s" % container)
		return false
	return GBIS.add_item(container, soul)


static func has_container(container: String) -> bool:
	return ContainerRepository.instance.get_container(container) != null


static func get_container_names() -> PackedStringArray:
	var names := PackedStringArray()
	for name in GBIS.inventory_names:
		if not names.has(name):
			names.append(name)
	for name in GBIS.shop_names:
		if not names.has(name):
			names.append(name)
	names.sort()
	return names


static func show_shop() -> bool:
	var window := _shop_window()
	if window == null:
		return false
	if not window.visible and not COMMON.show_window(window):
		return false
	return true


static func shop_add_soul(id : StringName) -> bool:
	var soul := ModLoader.get_soul(id)
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


static func cancel_moving_item() -> bool:
	return GBIS.moving_item_service.cancel()


static func drop_moving_item(container : String, grid_id : Vector2i) -> bool:
	return GBIS.moving_item_service.drop_on_grid(container, grid_id)


static func sell_moving_item() -> bool:
	return GBIS.moving_item_service.sell_dragged()


static func quick_sell(container : String, grid_id : Vector2i) -> bool:
	return GBIS.inventory_service.quick_sell(container, grid_id)


static func set_warehouse_page(page : int) -> bool:
	var window := _inventory_window()
	if window == null:
		push_warning("TestAPI：找不到仓库窗口")
		return false
	window.set_page(page)
	return true


static func get_warehouse_page() -> int:
	var window := _inventory_window()
	return window.get_page() if window != null else -1


static func add_vessel(id : StringName, container : String = "") -> bool:
	var vessel := ModLoader.get_vessel(id)
	if vessel == null:
		push_warning("TestAPI：魂器不存在 %s" % id)
		return false
	if container.is_empty():
		return Warehouse.add_item(vessel)
	return GBIS.add_item(container, vessel)


static func equip_vessel(id : StringName) -> bool:
	var vessel := ModLoader.get_vessel(id)
	if vessel == null:
		push_warning("TestAPI：魂器不存在 %s" % id)
		return false
	return GBIS.add_item(CONTAINER_IDS.VESSEL_GRID, vessel)


static func vessel_add_soul(soul_id : StringName, vessel_slot : int = 0) -> bool:
	var soul := ModLoader.get_soul(soul_id)
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


static func get_vessel_contents(vessel_slot : int = 0) -> Array[String]:
	var names : Array[String] = []
	var vessel := _equipped_vessel(vessel_slot)
	if vessel == null:
		return names
	for item in vessel.ensure_contents().items:
		if item != null:
			names.append(item.item_name)
	return names


static func get_vessel_ids() -> Array[StringName]:
	return ModLoader.get_vessel_ids()


static func get_equipped_vessel_tooltip_text(vessel_slot : int = 0) -> String:
	return _equipped_vessel_tooltip(vessel_slot, TooltipText.Format.PLAIN)


static func get_equipped_vessel_tooltip_bbcode(vessel_slot : int = 0) -> String:
	return _equipped_vessel_tooltip(vessel_slot, TooltipText.Format.BBCODE)


static func get_equipped_vessel_tooltip_ansi(vessel_slot : int = 0) -> String:
	return _equipped_vessel_tooltip(vessel_slot, TooltipText.Format.ANSI)


static func clear_container(container : String) -> void:
	var data := ContainerRepository.instance.get_container(container)
	if data == null:
		return
	data.clear()
	GBIS.sig_inv_refresh.emit()


static func get_container_items(container : String) -> Array[String]:
	var names : Array[String] = []
	var data := ContainerRepository.instance.get_container(container)
	if data == null:
		return names
	for item in data.items:
		if item != null:
			names.append(item.item_name)
	return names


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


static func set_unlock_all(enabled : bool) -> void:
	CollectionDB.set_unlock_all_for_testing(enabled)


static func unlock_all_collection() -> bool:
	return CollectionDB.unlock_all()


static func get_seen_ids(kind : int) -> Array[StringName]:
	return CollectionDB.get_seen_ids(kind)


static func is_seen(kind : int, id : StringName) -> bool:
	return CollectionDB.is_seen(kind, id)


static func get_soul_ids() -> Array[StringName]:
	return ModLoader.get_soul_ids()


static func get_soul_types(id : StringName) -> Array[StringName]:
	var soul := ModLoader.get_soul(id)
	if soul == null:
		return []
	return soul.types.duplicate()


static func get_soul_tags(id : StringName) -> Array[StringName]:
	var soul := ModLoader.get_soul(id)
	if soul == null:
		return []
	return soul.tags.duplicate()


static func get_soul_size_tag(id : StringName) -> StringName:
	var soul := ModLoader.get_soul(id)
	return soul.size_tag() if soul != null else &""


static func get_vessel_tooltip_text(id : StringName) -> String:
	return _vessel_tooltip(id, TooltipText.Format.PLAIN)


static func get_vessel_tooltip_bbcode(id : StringName) -> String:
	return _vessel_tooltip(id, TooltipText.Format.BBCODE)


static func get_vessel_tooltip_ansi(id : StringName) -> String:
	return _vessel_tooltip(id, TooltipText.Format.ANSI)


static func get_skill_tags() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in ModLoader.get_soul_ids():
		var soul := ModLoader.get_soul(id)
		if soul == null or soul.skill == null:
			continue
		result.append({
			"content_id": String(id),
			"skill_id": soul.skill.id,
			"ability_tag": "Skill." + soul.skill.id,
		})
	return result


static func get_soul_card_info(id : StringName) -> Dictionary:
	var soul := ModLoader.get_soul(id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % id)
		return {}
	return {
		"icon": soul.icon.resource_path if soul.icon != null else "",
		"columns": soul.columns,
		"rows": soul.rows,
		"label": soul.item_name,
	}


static func get_soul_damage_scaling(id : StringName) -> Dictionary:
	var soul := ModLoader.get_soul(id)
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


static func get_soul_steps(id : StringName) -> Array[Dictionary]:
	var soul := ModLoader.get_soul(id)
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
			info["projectile"] = unit_step.uses_projectile
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


static func get_soul_cast_times(id : StringName) -> int:
	var soul := ModLoader.get_soul(id)
	if soul == null or soul.skill == null:
		return 0
	return maxi(soul.skill.cast_times, 1)


static func get_soul_tooltip_text(id : StringName) -> String:
	return _soul_tooltip(id, TooltipText.Format.PLAIN)


static func get_soul_tooltip_bbcode(id : StringName) -> String:
	return _soul_tooltip(id, TooltipText.Format.BBCODE)


static func get_soul_tooltip_ansi(id : StringName) -> String:
	return _soul_tooltip(id, TooltipText.Format.ANSI)


static func get_equipped_soul_tooltip_text(id : StringName) -> String:
	return _equipped_soul_tooltip(id, TooltipText.Format.PLAIN)


static func get_equipped_soul_tooltip_bbcode(id : StringName) -> String:
	return _equipped_soul_tooltip(id, TooltipText.Format.BBCODE)


static func get_equipped_soul_tooltip_ansi(id : StringName) -> String:
	return _equipped_soul_tooltip(id, TooltipText.Format.ANSI)


static func get_monster_ids() -> Array[StringName]:
	return ModLoader.get_monster_ids()


static func get_monster_spawn_distances(id : StringName) -> Array[int]:
	var monster := ModLoader.get_monster(id)
	if monster == null:
		push_warning("TestAPI：怪物不存在 %s" % id)
		return []
	return monster.spawn_distances.duplicate()


static func _format_tooltip(
	title : String, body : String, format : TooltipText.Format
) -> String:
	var shown_title := title
	if format == TooltipText.Format.ANSI:
		shown_title = TooltipText.title_ansi(title)
	return "%s\n%s" % [shown_title, body]


static func _soul_tooltip(id : StringName, format : TooltipText.Format) -> String:
	var soul := ModLoader.get_soul(id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % id)
		return ""
	return _format_tooltip(soul.item_name, SoulTooltip.build(soul, format), format)


static func _equipped_soul_tooltip(id : StringName, format : TooltipText.Format) -> String:
	var context := _equipped_soul_context(id)
	if context.is_empty():
		return _soul_tooltip(id, format)
	var soul := context["soul"] as SoulData
	var preview := context["preview"] as SoulDamagePreview
	return _format_tooltip(soul.item_name, SoulTooltip.build(soul, format, preview), format)


static func _vessel_tooltip(id : StringName, format : TooltipText.Format) -> String:
	var vessel := ModLoader.get_vessel(id)
	if vessel == null:
		push_warning("TestAPI：魂器不存在 %s" % id)
		return ""
	return _format_tooltip(vessel.item_name, VesselTooltip.build(vessel, format), format)


static func _equipped_vessel_tooltip(
	vessel_slot : int, format : TooltipText.Format
) -> String:
	var vessel := _equipped_vessel(vessel_slot)
	if vessel == null:
		return ""
	return _format_tooltip(vessel.item_name, VesselTooltip.build(vessel, format), format)


static func _equipped_vessel(vessel_slot : int) -> SoulVesselData:
	var container := ContainerRepository.instance.get_container(CONTAINER_IDS.VESSEL_GRID)
	if container == null:
		return null
	var vessels := SoulVesselData.combat_vessels_in(container)
	if vessel_slot < 0 or vessel_slot >= vessels.size():
		return null
	return vessels[vessel_slot]


static func _inventory_window() -> InventoryWindow:
	var window := COMMON.find_node_in_scene(InventoryWindow) as InventoryWindow
	if window != null:
		return window
	var ui := COMMON.find_node_in_scene(GameUI) as GameUI
	return ui.ensure_panel(&"inventory") as InventoryWindow if ui != null else null


static func _shop_window() -> BaseWindow:
	var window := COMMON.find_node_in_scene(BaseWindow, &"ShopWindow") as BaseWindow
	if window != null:
		return window
	var ui := COMMON.find_node_in_scene(GameUI) as GameUI
	return ui.ensure_panel(&"shop") if ui != null else null


static func _player_runtime_for(id : StringName) -> SoulRuntime:
	for runtime in SoulRuntimeDB.player_runtimes():
		if runtime.soul != null and runtime.soul.content_id == id:
			return runtime
	return null


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


static func _equipped_soul_entry(id : StringName) -> Dictionary:
	var grid := ContainerRepository.instance.get_container(CONTAINER_IDS.VESSEL_GRID)
	if grid == null:
		return {}
	for vessel in SoulVesselData.combat_vessels_in(grid):
		for item in vessel.ensure_contents().items:
			if item is SoulData and (item as SoulData).content_id == id:
				return {"soul": item as SoulData, "vessel": vessel}
	return {}
