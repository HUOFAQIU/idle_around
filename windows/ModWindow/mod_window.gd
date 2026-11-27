class_name ModWindow extends BaseWindow

const MOD_PATHS: GDScript = preload("res://scripts/mod/mod_paths.gd")
const MODS_DIR: String = MOD_PATHS.USER_MODS_DIR

var _tabs: TabContainer
var _summary_label: Label
var _list_box: VBoxContainer
var _order_box: VBoxContainer
var _status_label: Label
var _startup_enabled: Dictionary[StringName, bool] = {}
var _startup_order: Array[StringName] = []


func _ready() -> void:
	super._ready()
	title = "Mod 管理"
	size = Vector2(760, 520)
	visibility_changed.connect(_on_visibility_changed)
	_build_ui()
	for mod in ModLoader.get_mod_list():
		_startup_enabled[StringName(mod.get("id", ""))] = bool(mod.get("enabled", true))
	_startup_order = ModLoader.get_user_order()
	refresh()


func refresh() -> void:
	if _list_box == null:
		return
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()

	var mods := ModLoader.get_mod_list()
	var loaded := 0
	var blocked := 0
	var pending := 0
	for mod in mods:
		if bool(mod.get("loaded", false)):
			loaded += 1
		if bool(mod.get("blocked", false)):
			blocked += 1
		if _has_pending(mod):
			pending += 1
		_add_mod_row(mod)
	var error_count := ModLoader.get_errors().size()
	var warning_count := ModLoader.get_warnings().size()

	if mods.is_empty():
		var empty := Label.new()
		empty.text = "没有发现内置 core 或 user://mods 下的 mod。\n第三方 mod：把 mod.json（可选 content.pck）放进 user://mods/<mod_id>/ 后重启游戏。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", GameColors.to_color(GameColors.TEXT_SECONDARY))
		_list_box.add_child(empty)

	_add_global_errors(mods)
	_add_global_warnings(mods)
	_rebuild_order()
	_summary_label.text = "%d 个 mod · %d 个已加载 · %d 个被阻止 · %d 个错误 · %d 个警告" % [
		mods.size(),
		loaded,
		blocked,
		error_count,
		warning_count,
	]
	_update_status(pending)


func get_test_state() -> Dictionary:
	var mods := ModLoader.get_mod_list()
	var loaded := 0
	var pending := 0
	for mod in mods:
		if bool(mod.get("loaded", false)):
			loaded += 1
		if _has_pending(mod):
			pending += 1
	var order_ids: Array[String] = []
	for mod_id in ModLoader.get_user_order():
		order_ids.append(String(mod_id))
	var load_ids: Array[String] = []
	for mod_id in ModLoader.get_load_order():
		load_ids.append(String(mod_id))
	return {
		"visible": visible,
		"mods": mods.size(),
		"loaded": loaded,
		"pending": pending,
		"order_pending": _order_pending(),
		"order": order_ids,
		"load_order": load_ids,
		"errors": ModLoader.get_errors().size(),
		"warnings": ModLoader.get_warnings().size(),
		"summary": _summary_label.text if _summary_label != null else "",
	}


func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var title_label := Label.new()
	title_label.text = "已发现的 Mod"
	title_label.add_theme_font_size_override("font_size", 18)
	header.add_child(title_label)

	_summary_label = Label.new()
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.TEXT_SECONDARY))
	header.add_child(_summary_label)

	var refresh_button := Button.new()
	refresh_button.text = "刷新"
	refresh_button.tooltip_text = "重新读取当前 mod 状态；新增/删除 mod 需要重启游戏"
	refresh_button.pressed.connect(refresh)
	header.add_child(refresh_button)

	var open_button := Button.new()
	open_button.text = "打开 mod 目录"
	open_button.tooltip_text = "第三方 mod 目录：%s（内置 core 在游戏包内）" % ProjectSettings.globalize_path(MODS_DIR)
	open_button.pressed.connect(_open_mods_dir)
	header.add_child(open_button)

	vbox.add_child(HSeparator.new())

	_tabs = TabContainer.new()
	_tabs.name = "Tabs"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tabs)
	_build_list_tab()
	_build_order_tab()

	vbox.add_child(HSeparator.new())

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.DEBUG_TEXT))
	vbox.add_child(_status_label)


func _build_list_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Mod 列表"
	tab.add_theme_constant_override("separation", 4)
	_tabs.add_child(tab)

	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.name = "ModList"
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 4)
	scroll.add_child(_list_box)


func _build_order_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "加载顺序"
	tab.add_theme_constant_override("separation", 4)
	_tabs.add_child(tab)

	var hint := Label.new()
	hint.text = "调整基础加载顺序；dependencies 和 load_after 仍会强制调整，冲突时以依赖为准。修改后重启游戏生效。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", GameColors.to_color(GameColors.DEBUG_HINT))
	tab.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.name = "OrderScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab.add_child(scroll)

	_order_box = VBoxContainer.new()
	_order_box.name = "OrderList"
	_order_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_order_box.add_theme_constant_override("separation", 4)
	scroll.add_child(_order_box)


func _add_mod_row(mod: Dictionary) -> void:
	var mod_id := StringName(mod.get("id", ""))
	var builtin := bool(mod.get("builtin", false))
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_list_box.add_child(row)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	row.add_child(top)

	var check := CheckBox.new()
	check.button_pressed = bool(mod.get("enabled", true))
	check.disabled = builtin
	check.tooltip_text = "内置 mod 不能禁用" if builtin else "启用/禁用；保存到 user://mods.cfg，重启游戏后生效"
	check.toggled.connect(_on_mod_toggled.bind(mod_id))
	top.add_child(check)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	top.add_child(info)

	var display_name := String(mod.get("name", ""))
	var name_label := Label.new()
	name_label.text = display_name if not display_name.is_empty() else String(mod_id)
	name_label.add_theme_font_size_override("font_size", 15)
	info.add_child(name_label)

	var meta_parts: Array[String] = [String(mod_id)]
	if builtin:
		meta_parts.append("内置")
	var version := String(mod.get("version", ""))
	if not version.is_empty():
		meta_parts.append("v" + version)
	var author := String(mod.get("author", ""))
	if not author.is_empty():
		meta_parts.append(author)
	var meta := Label.new()
	meta.text = " · ".join(meta_parts)
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", GameColors.to_color(GameColors.TEXT_SECONDARY))
	info.add_child(meta)

	var description := String(mod.get("description", ""))
	if not description.is_empty():
		var desc := Label.new()
		desc.text = description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", GameColors.to_color(GameColors.DEBUG_HINT))
		info.add_child(desc)

	var status := Label.new()
	status.text = _status_text(mod)
	status.add_theme_color_override("font_color", _status_color(mod))
	top.add_child(status)

	var content := Label.new()
	content.text = "魂灵 %d · 怪物 %d · 魂器 %d · Cue %d" % [
		int(mod.get("souls", 0)),
		int(mod.get("monsters", 0)),
		int(mod.get("vessels", 0)),
		int(mod.get("cues", 0)),
	]
	var load_index := int(mod.get("load_index", -1))
	if load_index >= 0:
		content.text += " · 顺序 %d" % (load_index + 1)
	content.add_theme_font_size_override("font_size", 12)
	content.add_theme_color_override("font_color", GameColors.to_color(GameColors.TEXT_SECONDARY))
	top.add_child(content)

	var mod_errors: Array = mod.get("errors", [])
	for message in mod_errors:
		var error_label := Label.new()
		error_label.text = "! " + String(message)
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		error_label.add_theme_font_size_override("font_size", 12)
		error_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.DAMAGE))
		row.add_child(error_label)

	var mod_warnings: Array = mod.get("warnings", [])
	for message in mod_warnings:
		var warning_label := Label.new()
		warning_label.text = "? " + String(message)
		warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning_label.add_theme_font_size_override("font_size", 12)
		warning_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.WARNING))
		row.add_child(warning_label)

	_list_box.add_child(HSeparator.new())


func _add_global_errors(mods: Array[Dictionary]) -> void:
	var known: Dictionary[String, bool] = {}
	for mod in mods:
		for message in mod.get("errors", []):
			known[String(message)] = true
	var leftovers: Array[String] = []
	for message in ModLoader.get_errors():
		if not known.has(message):
			leftovers.append(message)
	if leftovers.is_empty():
		return

	var heading := Label.new()
	heading.text = "加载器错误"
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", GameColors.to_color(GameColors.DAMAGE))
	_list_box.add_child(heading)
	for message in leftovers:
		var label := Label.new()
		label.text = "! " + message
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", GameColors.to_color(GameColors.DAMAGE))
		_list_box.add_child(label)


func _add_global_warnings(mods: Array[Dictionary]) -> void:
	var known: Dictionary[String, bool] = {}
	for mod in mods:
		for message in mod.get("warnings", []):
			known[String(message)] = true
	var leftovers: Array[String] = []
	for message in ModLoader.get_warnings():
		if not known.has(message):
			leftovers.append(message)
	if leftovers.is_empty():
		return

	var heading := Label.new()
	heading.text = "加载器警告"
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", GameColors.to_color(GameColors.WARNING))
	_list_box.add_child(heading)
	for message in leftovers:
		var label := Label.new()
		label.text = "? " + message
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", GameColors.to_color(GameColors.WARNING))
		_list_box.add_child(label)


func _rebuild_order() -> void:
	for child in _order_box.get_children():
		_order_box.remove_child(child)
		child.queue_free()

	var order := ModLoader.get_user_order()
	for index in order.size():
		var mod := ModLoader.get_mod(order[index])
		if mod != null:
			_add_order_row(index, mod, order.size())


func _add_order_row(index: int, mod: ModInfo, count: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_order_box.add_child(row)

	var index_label := Label.new()
	index_label.text = "%d." % (index + 1)
	index_label.custom_minimum_size = Vector2(32, 0)
	index_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.TEXT_SECONDARY))
	row.add_child(index_label)

	var name_label := Label.new()
	name_label.text = "%s  (%s)" % [
		mod.name if not mod.name.is_empty() else String(mod.id),
		String(mod.id),
	]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var state := Label.new()
	state.text = _order_state_text(mod)
	state.add_theme_color_override("font_color", _order_state_color(mod))
	row.add_child(state)

	var builtin := mod.is_builtin()
	var order := ModLoader.get_user_order()
	var previous_builtin := index > 0 and ModLoader.get_mod(order[index - 1]).is_builtin()
	var up := Button.new()
	up.text = "↑"
	up.tooltip_text = "内置 mod 固定在最前" if builtin else "上移"
	up.disabled = builtin or index == 0 or previous_builtin
	up.pressed.connect(_move_order.bind(index, -1))
	row.add_child(up)

	var down := Button.new()
	down.text = "↓"
	down.tooltip_text = "内置 mod 固定在最前" if builtin else "下移"
	down.disabled = builtin or index >= count - 1
	down.pressed.connect(_move_order.bind(index, 1))
	row.add_child(down)

	_order_box.add_child(HSeparator.new())


func _move_order(index: int, delta: int) -> void:
	var order := ModLoader.get_user_order()
	if index < 0 or index >= order.size():
		return
	var target := index + delta
	if target < 0 or target >= order.size():
		return
	var mod_id := order[index]
	var moving := ModLoader.get_mod(mod_id)
	if moving == null or moving.is_builtin():
		return
	var target_mod := ModLoader.get_mod(order[target])
	if target_mod != null and target_mod.is_builtin():
		return
	order.remove_at(index)
	order.insert(target, mod_id)
	var saved := ModLoader.set_mod_order(order)
	refresh()
	if not saved:
		_status_label.text = "写入 user://mods.cfg 失败；重启后可能恢复原顺序。"
		_status_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.DAMAGE))


func _order_state_text(mod: ModInfo) -> String:
	if mod.blocked:
		return "被阻止"
	if mod.is_builtin():
		return "内置" if not mod.loaded else "内置 · 已加载"
	if not mod.enabled:
		return "已禁用"
	return "已加载" if mod.loaded else "未加载"


func _order_state_color(mod: ModInfo) -> Color:
	if mod.blocked:
		return GameColors.to_color(GameColors.DAMAGE)
	if not mod.enabled:
		return GameColors.to_color(GameColors.TEXT_DISABLED)
	if mod.loaded:
		return GameColors.to_color(GameColors.SUCCESS)
	return GameColors.to_color(GameColors.WARNING)


func _status_text(mod: Dictionary) -> String:
	var parts: Array[String] = []
	if bool(mod.get("blocked", false)):
		parts.append("被阻止")
	elif not bool(mod.get("enabled", true)):
		parts.append("已禁用")
	elif bool(mod.get("loaded", false)):
		parts.append("已加载")
		if bool(mod.get("builtin", false)):
			parts.append("内置")
		else:
			parts.append("PCK" if bool(mod.get("mounted", false)) else "目录")
	else:
		parts.append("未加载")
	if _has_pending(mod):
		parts.append("重启后生效")
	return " · ".join(parts)


func _status_color(mod: Dictionary) -> Color:
	var mod_errors: Array = mod.get("errors", [])
	if bool(mod.get("blocked", false)) or not mod_errors.is_empty():
		return GameColors.to_color(GameColors.DAMAGE)
	var mod_warnings: Array = mod.get("warnings", [])
	if not mod_warnings.is_empty():
		return GameColors.to_color(GameColors.WARNING)
	if _has_pending(mod):
		return GameColors.to_color(GameColors.WARNING)
	if not bool(mod.get("enabled", true)):
		return GameColors.to_color(GameColors.TEXT_DISABLED)
	if bool(mod.get("loaded", false)):
		return GameColors.to_color(GameColors.SUCCESS)
	return GameColors.to_color(GameColors.WARNING)


func _has_pending(mod: Dictionary) -> bool:
	var mod_id := StringName(mod.get("id", ""))
	if not _startup_enabled.has(mod_id):
		return false
	return bool(mod.get("enabled", true)) != bool(_startup_enabled[mod_id])


func _order_pending() -> bool:
	return ModLoader.get_user_order() != _startup_order


func _update_status(pending: int) -> void:
	var order_pending := _order_pending()
	if pending == 0 and not order_pending:
		_status_label.text = "启用状态和加载顺序保存到 user://mods.cfg；重启游戏后生效。"
		_status_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.DEBUG_TEXT))
		return
	var parts: Array[String] = []
	if pending > 0:
		parts.append("%d 个启用状态改动" % pending)
	if order_pending:
		parts.append("加载顺序改动")
	_status_label.text = "有 %s，重启游戏后生效。" % "、".join(parts)
	_status_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.WARNING))


func _on_mod_toggled(pressed: bool, mod_id: StringName) -> void:
	var saved := ModLoader.set_mod_enabled(mod_id, pressed)
	refresh()
	if not saved:
		_status_label.text = "写入 user://mods.cfg 失败：%s；重启后可能恢复原状态。" % mod_id
		_status_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.DAMAGE))


func _on_visibility_changed() -> void:
	if visible:
		refresh()


func _open_mods_dir() -> void:
	var path := ProjectSettings.globalize_path(MODS_DIR)
	var err := OS.shell_open(path)
	if err != OK:
		_status_label.text = "无法打开目录：%s" % path
		_status_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.DAMAGE))
