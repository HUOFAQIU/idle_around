## 调试窗口“总览/魂灵”页的一行魂灵状态。
##
## 只读 SoulRuntime，不反向改战斗状态；由 DebugWindow 定时调用 refresh()。
extends PanelContainer

var runtime: SoulRuntime

var _icon: TextureRect
var _name_label: Label
var _part_label: Label
var _charge_bar: ProgressBar
var _charge_label: Label
var _status_label: Label
var _counter_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(0, 30)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(24, 24)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_icon)

	_name_label = Label.new()
	_name_label.custom_minimum_size = Vector2(80, 0)
	_name_label.clip_text = true
	row.add_child(_name_label)

	_part_label = Label.new()
	_part_label.custom_minimum_size = Vector2(66, 0)
	_part_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.DEBUG_HINT))
	row.add_child(_part_label)

	_charge_bar = ProgressBar.new()
	_charge_bar.custom_minimum_size = Vector2(150, 16)
	_charge_bar.show_percentage = false
	_charge_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_charge_bar)

	_charge_label = Label.new()
	_charge_label.custom_minimum_size = Vector2(96, 0)
	row.add_child(_charge_label)

	_status_label = Label.new()
	_status_label.custom_minimum_size = Vector2(150, 0)
	_status_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.DEBUG_STATUS))
	row.add_child(_status_label)

	_counter_label = Label.new()
	_counter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.DEBUG_COUNTER))
	row.add_child(_counter_label)


func bind(p_runtime: SoulRuntime) -> void:
	runtime = p_runtime
	refresh()


func refresh() -> void:
	if runtime == null:
		return
	if runtime.soul != null:
		_icon.texture = runtime.soul.icon
	_name_label.text = runtime.display_name()
	_part_label.text = _part_text()

	if runtime.ability == null:
		_charge_bar.value = 0.0
		_charge_label.text = "被动"
		_status_label.text = ""
		_name_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.DEBUG_NAME))
	else:
		var ability := runtime.ability
		_charge_bar.value = runtime.scanline_progress * 100.0
		_charge_label.text = "%.1f/%.1fs" % [ability.charge_seconds(), ability.cooldown]
		var statuses: Array[String] = []
		if runtime.haste_seconds > 0.0:
			statuses.append("加速 %.1f" % runtime.haste_seconds)
		if runtime.slow_seconds > 0.0:
			statuses.append("减速 %.1f" % runtime.slow_seconds)
		if runtime.freeze_seconds > 0.0:
			statuses.append("冻结 %.1f" % runtime.freeze_seconds)
		elif ability.is_frozen():
			statuses.append("单位冻结")
		if ability.is_active:
			statuses.append("施法中")
		if ability.activation_lock_seconds() > 0.0:
			statuses.append("锁 %.1f" % ability.activation_lock_seconds())
		_status_label.text = "  ".join(statuses)
		_name_label.add_theme_color_override(
			"font_color",
			GameColors.to_color(GameColors.SUCCESS) if ability.is_ready() and not ability.is_frozen()
			else GameColors.to_color(GameColors.INFO)
		)

	_counter_label.text = "激活 %d | 触发 %d | 收充能 %.1fs" % [
		int(runtime.counter("activations")),
		int(runtime.counter("triggers_fired")),
		runtime.counter("charges_received"),
	]


func _part_text() -> String:
	if runtime == null or runtime.slot == null:
		return ""
	match runtime.slot.container_name:
		"cell_0":
			return "头部"
		"cell_1":
			return "身体"
		"cell_2":
			return "手部"
		"cell_3":
			return "腿部"
		_:
			return runtime.slot.container_name
