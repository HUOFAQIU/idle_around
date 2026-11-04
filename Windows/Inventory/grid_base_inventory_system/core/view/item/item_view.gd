extends Control
## 物品视图，控制物品的绘制
class_name ItemView

## 魂灵状态徽章：加速在上、冻结在中、减速在下
const HASTE_BADGE_SCENE := preload("res://game/content/Kits/jiasu.tscn")
const SLOW_BADGE_SCENE := preload("res://game/content/Kits/jiansu.tscn")
const FREEZE_BADGE_SCENE := preload("res://game/content/Kits/bingdong.tscn")
const STATUS_BADGE_SIZE := Vector2(16.0, 10.0)
const BADGE_TOP : int = 0
const BADGE_CENTER : int = 1
const BADGE_BOTTOM : int = 2

## 魂灵名称标签：字号按卡面宽度缩放，最小 12 保证可读
const SOUL_NAME_FONT_RATIO : float = 0.2
const SOUL_NAME_MIN_FONT_SIZE : int = 12
const SOUL_NAME_MAX_FONT_SIZE : int = 20
const SOUL_NAME_OUTLINE_SIZE : int = 2

## 堆叠数字的字体
var stack_num_font: Font
## 堆叠数字的字体大小
var stack_num_font_size: int
## 堆叠数字的边距
var stack_num_margin: int = 4
## 堆叠数字的颜色
var stack_num_color: Color = GameColors.STACK_NUM_COLOR

## 物品数据
var data: ItemData
## 绘制基础大小（格子大小）
var base_size: int:
	set(value):
		base_size = value
		call_deferred("recalculate_size")
## 是否正在移动
var _is_moving: bool = false
## 移动偏移量（坐标）
var _moving_offset: Vector2i = Vector2i.ZERO
## 魂灵名称标签（只对 SoulData 创建）
var _soul_name_label: Label
## 状态徽章（只对 SoulData 创建）
var _haste_badge: Control
var _slow_badge: Control
var _freeze_badge: Control
## 战斗运行期状态；仓库副本没有，只有正在装备/战斗中的魂灵才有
var _runtime: SoulRuntime

## 构造函数
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
	# 如果 material 不为空，则加上 material
	if data.material:
		material = data.material.duplicate()
	elif GBIS.item_material:
		material = GBIS.item_material.duplicate()
	# 魂灵扫描线的固定色从 GameColors 写进副本；shader 默认值只作兜底
	if data is SoulData and material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		shader_material.set_shader_parameter("line_color", GameColors.to_color(GameColors.SOUL_LINE))
		shader_material.set_shader_parameter("freeze_color", GameColors.to_color(GameColors.SOUL_FREEZE))
	data.sig_refresh.connect(_on_data_refresh)

## 入树后创建魂灵状态徽章，并尝试绑定战斗运行期状态
func _ready() -> void:
	if data is SoulData:
		_soul_name_label = _make_soul_name_label()
		_refresh_soul_name_label()
		_haste_badge = _make_status_badge(HASTE_BADGE_SCENE, "HasteBadge")
		_slow_badge = _make_status_badge(SLOW_BADGE_SCENE, "SlowBadge")
		_freeze_badge = _make_status_badge(FREEZE_BADGE_SCENE, "FreezeBadge")
		SoulRuntimeDB.runtime_registered.connect(_on_runtime_registered)
		SoulRuntimeDB.runtime_unregistered.connect(_on_runtime_unregistered)
		_bind_runtime(SoulRuntimeDB.get_runtime(data as SoulData))
		_refresh_status_badges()
		_apply_freeze_shader()


func _exit_tree() -> void:
	if data is SoulData:
		if SoulRuntimeDB.runtime_registered.is_connected(_on_runtime_registered):
			SoulRuntimeDB.runtime_registered.disconnect(_on_runtime_registered)
		if SoulRuntimeDB.runtime_unregistered.is_connected(_on_runtime_unregistered):
			SoulRuntimeDB.runtime_unregistered.disconnect(_on_runtime_unregistered)
	_unbind_runtime()

## 重写计算大小
func recalculate_size() -> void:
	size = Vector2(data.columns * base_size, data.rows * base_size)
	queue_redraw()
	_refresh_soul_name_label()
	_refresh_status_badges()

## 移动
func move(offset: Vector2i = Vector2i.ZERO) -> void:
	_is_moving = true
	_moving_offset = offset

## 绘制物品
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

## 跟随鼠标
func _process(_delta: float) -> void:
	update_moving_position()


func update_moving_position() -> void:
	if not _is_moving:
		return
	@warning_ignore("integer_division")
	global_position = get_global_mouse_position() - Vector2(base_size * _moving_offset) - Vector2(base_size / 2, base_size / 2)


func _on_data_refresh() -> void:
	queue_redraw()
	_refresh_soul_name_label()
	_refresh_status_badges()
	_apply_freeze_shader()


## 战斗开始/结束时 SoulRuntimeDB 会广播注册/注销；只绑定同一份 SoulData
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
		_runtime.changed.connect(_on_runtime_changed)
	_set_progress_param(_runtime.scanline_progress if _runtime != null else 0.0)
	_refresh_status_badges()
	_apply_freeze_shader()


func _unbind_runtime() -> void:
	_bind_runtime(null)


## 运行期状态变化：只改材质参数和徽章，不重绘整个 ItemView
func _on_runtime_changed() -> void:
	_set_progress_param(_runtime.scanline_progress if _runtime != null else 0.0)
	_refresh_status_badges()
	_apply_freeze_shader()


func _set_progress_param(value: float) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("progress", value)


## 冻结状态直接改材质参数：冰霜覆盖不依赖 shader_params 里有没有登记 freeze
func _apply_freeze_shader() -> void:
	if not data is SoulData or not material is ShaderMaterial:
		return
	var frozen := _runtime != null and _runtime.freeze_seconds > 0.0
	(material as ShaderMaterial).set_shader_parameter("freeze", 1.0 if frozen else 0.0)


## 创建盖在卡面图标上的魂灵名称标签；父节点就是卡面，铺满即可
func _make_soul_name_label() -> Label:
	var label := Label.new()
	label.name = "SoulNameLabel"
	label.text = data.item_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_color_override("font_color", GameColors.to_color(GameColors.SOUL_NAME))
	label.add_theme_color_override("font_outline_color", GameColors.to_color(GameColors.SOUL_NAME_OUTLINE))
	label.add_theme_constant_override("outline_size", SOUL_NAME_OUTLINE_SIZE)
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return label


## 字号跟着卡面宽度走：1×2 小卡用小字，3×2 大卡用大字
func _refresh_soul_name_label() -> void:
	if _soul_name_label == null:
		return
	var font_size := clampi(
		roundi(size.x * SOUL_NAME_FONT_RATIO), SOUL_NAME_MIN_FONT_SIZE, SOUL_NAME_MAX_FONT_SIZE
	)
	_soul_name_label.add_theme_font_size_override("font_size", font_size)
	if _soul_name_label.text != data.item_name:
		_soul_name_label.text = data.item_name


## 实例化一个 Kits 徽章，尺寸固定 16×10，鼠标事件全部穿透
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


## 把 SoulRuntime 上的剩余秒数同步到三个徽章；仓库副本没有运行期状态就隐藏
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
