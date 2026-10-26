extends Control
## 物品视图，控制物品的绘制
class_name ItemView

## 魂灵状态徽章：加速在上、减速在下
const HASTE_BADGE_SCENE := preload("res://game/content/Kits/jiasu.tscn")
const SLOW_BADGE_SCENE := preload("res://game/content/Kits/jiansu.tscn")
const STATUS_BADGE_SIZE := Vector2(16.0, 10.0)

## 堆叠数字的字体
var stack_num_font: Font
## 堆叠数字的字体大小
var stack_num_font_size: int
## 堆叠数字的边距
var stack_num_margin: int = 4
## 堆叠数字的颜色
var stack_num_color: Color = Color.WHITE

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
## 状态徽章（只对 SoulData 创建）
var _haste_badge: Control
var _slow_badge: Control

## 构造函数
@warning_ignore("shadowed_variable")
func _init(data: ItemData, base_size: int, stack_num_font: Font = null, stack_num_font_size: int = 16, stack_num_margin: int = 2, stack_num_color: Color = Color.WHEAT) -> void:
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
	data.sig_refresh.connect(_on_data_refresh)

## 入树后创建魂灵状态徽章
func _ready() -> void:
	if data is SoulData:
		_haste_badge = _make_status_badge(HASTE_BADGE_SCENE, "HasteBadge")
		_slow_badge = _make_status_badge(SLOW_BADGE_SCENE, "SlowBadge")
		_refresh_status_badges()

## 重写计算大小
func recalculate_size() -> void:
	size = Vector2(data.columns * base_size, data.rows * base_size)
	queue_redraw()
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
			(material as ShaderMaterial).set_shader_parameter(param_name, data.shader_params[param_name])

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
	_refresh_status_badges()


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


## 把 SoulData 上的剩余秒数同步到两个徽章
func _refresh_status_badges() -> void:
	if not data is SoulData:
		return
	var soul := data as SoulData
	_update_status_badge(_haste_badge, soul.haste_seconds, true)
	_update_status_badge(_slow_badge, soul.slow_seconds, false)


func _update_status_badge(badge: Control, seconds: float, top: bool) -> void:
	if badge == null:
		return
	badge.visible = seconds > 0.0
	var x := roundf((size.x - STATUS_BADGE_SIZE.x) * 0.5)
	var y := 0.0 if top else roundf(size.y - STATUS_BADGE_SIZE.y)
	badge.position = Vector2(x, y)
	if not badge.visible:
		return
	var label := badge.get_node_or_null("Label") as Label
	if label != null:
		label.text = "%.1f" % seconds
