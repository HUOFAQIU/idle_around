extends Control
class_name ItemView

const HASTE_BADGE_SCENE := preload("res://game/content/Kits/jiasu.tscn")
const SLOW_BADGE_SCENE := preload("res://game/content/Kits/jiansu.tscn")
const FREEZE_BADGE_SCENE := preload("res://game/content/Kits/bingdong.tscn")
const STATUS_BADGE_SIZE := Vector2(16.0, 10.0)
const BADGE_TOP : int = 0
const BADGE_CENTER : int = 1
const BADGE_BOTTOM : int = 2

const ITEM_NAME_FONT_RATIO : float = 0.2
const ITEM_NAME_MIN_FONT_SIZE : int = 12
const ITEM_NAME_MAX_FONT_SIZE : int = 20
const ITEM_NAME_OUTLINE_SIZE : int = 2

var stack_num_font: Font
var stack_num_font_size: int
var stack_num_margin: int = 4
var stack_num_color: Color = GameColors.STACK_NUM_COLOR

var data: ItemData
var base_size: int:
	set(value):
		if base_size == value:
			return
		base_size = value
		call_deferred("recalculate_size")
var _name_label: Label
var _haste_badge: Control
var _slow_badge: Control
var _freeze_badge: Control
var _runtime: SoulRuntime

@warning_ignore("shadowed_variable")
func _init(data: ItemData, base_size: int, stack_num_font: Font = null, stack_num_font_size: int = 16, stack_num_margin: int = 2, stack_num_color: Color = GameColors.STACK_NUM_COLOR) -> void:
	self.data = data
	self.base_size = base_size
	self.stack_num_font = stack_num_font if stack_num_font else get_theme_font("font")
	self.stack_num_font_size = stack_num_font_size
	self.stack_num_margin = stack_num_margin
	self.stack_num_color = stack_num_color
	recalculate_size()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if data.material:
		material = data.material.duplicate()
	elif GBIS.item_material:
		material = GBIS.item_material.duplicate()
	if data is SoulData and material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		shader_material.set_shader_parameter("line_color", GameColors.to_color(GameColors.SOUL_LINE))
		shader_material.set_shader_parameter("freeze_color", GameColors.to_color(GameColors.SOUL_FREEZE))
	data.sig_refresh.connect(_on_data_refresh)

func _ready() -> void:
	if _shows_name_label():
		_name_label = _make_name_label()
		_refresh_name_label()
	if data is SoulData:
		SoulRuntimeDB.runtime_registered.connect(_on_runtime_registered)
		SoulRuntimeDB.runtime_unregistered.connect(_on_runtime_unregistered)
		_bind_runtime(SoulRuntimeDB.get_runtime(data as SoulData))
		_apply_freeze_shader()


func _exit_tree() -> void:
	if data is SoulData:
		if SoulRuntimeDB.runtime_registered.is_connected(_on_runtime_registered):
			SoulRuntimeDB.runtime_registered.disconnect(_on_runtime_registered)
		if SoulRuntimeDB.runtime_unregistered.is_connected(_on_runtime_unregistered):
			SoulRuntimeDB.runtime_unregistered.disconnect(_on_runtime_unregistered)
	_unbind_runtime()

func recalculate_size() -> void:
	size = Vector2(data.columns * base_size, data.rows * base_size)
	queue_redraw()
	_refresh_name_label()
	_refresh_status_badges()

func _draw() -> void:
	if data.icon:
		draw_texture_rect(data.icon, Rect2(Vector2.ZERO, size), false)
	if data is StackableData:
		var text_size = stack_num_font.get_string_size(str(data.current_amount), HORIZONTAL_ALIGNMENT_RIGHT, -1, stack_num_font_size)
		var pos = Vector2(
			size.x - text_size.x - stack_num_margin,
			size.y - stack_num_font.get_descent(stack_num_font_size) - stack_num_margin
		)
		draw_string(stack_num_font, pos, str(data.current_amount), HORIZONTAL_ALIGNMENT_RIGHT, -1, stack_num_font_size, stack_num_color)
	if material:
		for param_name in data.shader_params.keys():
			var value: Variant = data.shader_params[param_name]
			if data is SoulData and param_name == "progress":
				value = _runtime.scanline_progress if _runtime != null else 0.0
			(material as ShaderMaterial).set_shader_parameter(param_name, value)

func _on_data_refresh() -> void:
	queue_redraw()
	_refresh_name_label()
	_refresh_status_badges()
	_apply_freeze_shader()


func _on_runtime_registered(runtime: SoulRuntime) -> void:
	if data is SoulData and runtime.soul == data:
		_bind_runtime(runtime)


func _on_runtime_unregistered(runtime: SoulRuntime) -> void:
	if _runtime == runtime:
		_bind_runtime(null)


func _bind_runtime(runtime: SoulRuntime) -> void:
	if _runtime == runtime:
		return
	if _runtime != null and _runtime.changed.is_connected(_on_runtime_changed):
		_runtime.changed.disconnect(_on_runtime_changed)
	_runtime = runtime
	if _runtime != null:
		_ensure_status_badges()
		_runtime.changed.connect(_on_runtime_changed)
	_set_progress_param(_runtime.scanline_progress if _runtime != null else 0.0)
	_refresh_status_badges()
	_apply_freeze_shader()


func _unbind_runtime() -> void:
	_bind_runtime(null)


func _on_runtime_changed() -> void:
	_set_progress_param(_runtime.scanline_progress if _runtime != null else 0.0)
	_refresh_status_badges()
	_apply_freeze_shader()


func _set_progress_param(value: float) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("progress", value)


func _apply_freeze_shader() -> void:
	if not data is SoulData or not material is ShaderMaterial:
		return
	var frozen := _runtime != null and _runtime.freeze_seconds > 0.0
	(material as ShaderMaterial).set_shader_parameter("freeze", 1.0 if frozen else 0.0)


func _shows_name_label() -> bool:
	return (
		data is SoulData
		or data is SoulVesselData
		or data is MapItemData
		or data is QuantityStoneData
	)


func _make_name_label() -> Label:
	var label := Label.new()
	label.name = "ItemNameLabel"
	label.text = data.item_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_color_override("font_color", GameColors.to_color(GameColors.SOUL_NAME))
	label.add_theme_color_override("font_outline_color", GameColors.to_color(GameColors.SOUL_NAME_OUTLINE))
	label.add_theme_constant_override("outline_size", ITEM_NAME_OUTLINE_SIZE)
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return label


func _refresh_name_label() -> void:
	if _name_label == null:
		return
	var font_size := clampi(
		roundi(size.x * ITEM_NAME_FONT_RATIO), ITEM_NAME_MIN_FONT_SIZE, ITEM_NAME_MAX_FONT_SIZE
	)
	_name_label.add_theme_font_size_override("font_size", font_size)
	if _name_label.text != data.item_name:
		_name_label.text = data.item_name


func _ensure_status_badges() -> void:
	if not data is SoulData:
		return
	if _haste_badge == null:
		_haste_badge = _make_status_badge(HASTE_BADGE_SCENE, "HasteBadge")
	if _slow_badge == null:
		_slow_badge = _make_status_badge(SLOW_BADGE_SCENE, "SlowBadge")
	if _freeze_badge == null:
		_freeze_badge = _make_status_badge(FREEZE_BADGE_SCENE, "FreezeBadge")


func _make_status_badge(scene: PackedScene, badge_name: String) -> Control:
	var badge := scene.instantiate() as Control
	badge.name = badge_name
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in badge.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge.size = STATUS_BADGE_SIZE
	badge.position = Vector2.ZERO
	badge.visible = false
	return badge


func _refresh_status_badges() -> void:
	if not data is SoulData:
		return
	var haste := _runtime.haste_seconds if _runtime != null else 0.0
	var freeze := _runtime.freeze_seconds if _runtime != null else 0.0
	var slow := _runtime.slow_seconds if _runtime != null else 0.0
	_update_status_badge(_haste_badge, haste, BADGE_TOP)
	_update_status_badge(_freeze_badge, freeze, BADGE_CENTER)
	_update_status_badge(_slow_badge, slow, BADGE_BOTTOM)


func _update_status_badge(badge: Control, seconds: float, position_mode: int) -> void:
	if badge == null:
		return
	badge.visible = seconds > 0.0
	var x := roundf((size.x - STATUS_BADGE_SIZE.x) * 0.5)
	var y := 0.0
	match position_mode:
		BADGE_TOP:
			y = 0.0
		BADGE_CENTER:
			y = roundf((size.y - STATUS_BADGE_SIZE.y) * 0.5)
		BADGE_BOTTOM:
			y = roundf(size.y - STATUS_BADGE_SIZE.y)
	badge.position = Vector2(x, y)
	if not badge.visible:
		return
	var label := badge.get_node_or_null("Label") as Label
	if label != null:
		label.text = "%.1f" % seconds
