class_name CollectionWindow
extends BaseWindow
## 见闻：已遇见的怪物、魂灵与魂器。
##
## 全量条目来自 CollectionDB（底层是 ModLoader 的 core + 第三方 mod 条目）；
## 未遇见的条目也占位显示，只是不暴露名字和图标。
## 魂灵/魂器页的已遇见条目：悬停显示 tooltip，右键放入仓库并播放抛物线飞入动画。

const LOCKED_NAME: String = "？？？"
## 右键入包成功后的抛物线动画：时长、弧高、图标大小、终点距右边缘的留白
const FLY_DURATION: float = 0.2
const FLY_ARC_HEIGHT: float = 110.0
const FLY_GHOST_SIZE: float = 64.0
const FLY_END_MARGIN: float = 24.0

@onready var monster_button: Button = $Root/VBox/KindRow/MonsterButton
@onready var soul_button: Button = $Root/VBox/KindRow/SoulButton
@onready var vessel_button: Button = $Root/VBox/KindRow/VesselButton
@onready var entry_grid: GridContainer = $Root/VBox/Body/Scroll/EntryGrid
@onready var hint_label: Label = $Root/VBox/HintLabel
## 飞入动画层；必须在 BaseWindow 把 Root 挪进内容区之前解析，之后按绝对路径会找不到
@onready var fly_layer: Control = $Root/FlyLayer

## 当前分类：ContentKind.Kind
var _kind: int = ContentKind.Kind.MONSTER
## 标题栏“全解锁”按钮：永久写入全部见闻
var _unlock_all_button: Button


func _ready() -> void:
	super()
	title = "见闻"
	_build_unlock_all_button()
	monster_button.pressed.connect(_select_kind.bind(ContentKind.Kind.MONSTER))
	soul_button.pressed.connect(_select_kind.bind(ContentKind.Kind.SOUL))
	vessel_button.pressed.connect(_select_kind.bind(ContentKind.Kind.VESSEL))
	CollectionDB.entry_unlocked.connect(_on_entry_unlocked)
	CollectionDB.state_reloaded.connect(_on_state_reloaded)
	visibility_changed.connect(_on_visibility_changed)
	hint_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.TEXT_SECONDARY))
	_select_kind(ContentKind.Kind.MONSTER)


## 切换怪物 / 魂灵 / 魂器页签
func _select_kind(kind: int) -> void:
	_kind = kind
	monster_button.button_pressed = kind == ContentKind.Kind.MONSTER
	soul_button.button_pressed = kind == ContentKind.Kind.SOUL
	vessel_button.button_pressed = kind == ContentKind.Kind.VESSEL
	_update_hint()
	_refresh()


## 底部提示跟着页签走
func _update_hint() -> void:
	match _kind:
		ContentKind.Kind.MONSTER:
			hint_label.text = "怪物：首次刷出即解锁"
		ContentKind.Kind.SOUL:
			hint_label.text = "右键已遇见魂灵：放入仓库"
		ContentKind.Kind.VESSEL:
			hint_label.text = "右键已遇见魂器：放入仓库"


## 标题栏按钮：一次性永久解锁全部见闻，不提供还原
func _build_unlock_all_button() -> void:
	_unlock_all_button = Button.new()
	_unlock_all_button.name = "UnlockAllButton"
	_unlock_all_button.text = "全解锁"
	_unlock_all_button.tooltip_text = "永久解锁全部见闻并保存"
	_unlock_all_button.custom_minimum_size = Vector2i(0, TITLE_BUTTON_SIZE.y)
	_unlock_all_button.pressed.connect(_on_unlock_all_pressed)
	add_title_bar_button(_unlock_all_button)


func _on_unlock_all_pressed() -> void:
	if CollectionDB.unlock_all():
		_refresh()


func _refresh() -> void:
	_hide_tooltip()
	for child in entry_grid.get_children():
		entry_grid.remove_child(child)
		child.queue_free()

	for id in _sorted_ids():
		entry_grid.add_child(_make_entry_cell(id))


func _sorted_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	match _kind:
		ContentKind.Kind.MONSTER:
			ids.assign(CollectionDB.get_monster_ids())
		ContentKind.Kind.SOUL:
			ids.assign(CollectionDB.get_soul_ids())
		ContentKind.Kind.VESSEL:
			ids.assign(CollectionDB.get_vessel_ids())
	ids.sort_custom(func(a, b): return _entry_name(a) < _entry_name(b))
	return ids


## 排序和条目显示都用它：怪物取 display_name，魂灵/魂器取 item_name
func _entry_name(id: StringName) -> String:
	match _kind:
		ContentKind.Kind.MONSTER:
			var monster := CollectionDB.get_monster(id)
			return monster.display_name if monster != null else String(id)
		ContentKind.Kind.SOUL:
			var soul := CollectionDB.get_soul(id)
			return soul.item_name if soul != null else String(id)
		ContentKind.Kind.VESSEL:
			var vessel := CollectionDB.get_vessel(id)
			return vessel.item_name if vessel != null else String(id)
	return String(id)


func _entry_icon(id: StringName) -> Texture2D:
	match _kind:
		ContentKind.Kind.MONSTER:
			var monster := CollectionDB.get_monster(id)
			return monster.icon if monster != null else null
		ContentKind.Kind.SOUL:
			var soul := CollectionDB.get_soul(id)
			return soul.icon if soul != null else null
		ContentKind.Kind.VESSEL:
			var vessel := CollectionDB.get_vessel(id)
			return vessel.icon if vessel != null else null
	return null


func _make_entry_cell(id: StringName) -> Control:
	var seen := CollectionDB.is_seen(_kind, id)
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)

	var button := Button.new()
	button.custom_minimum_size = Vector2(96, 96)
	button.icon = _entry_icon(id)
	button.expand_icon = true
	if not seen:
		button.modulate = GameColors.to_color(GameColors.LOCKED_MODULATE)
	elif _kind == ContentKind.Kind.SOUL or _kind == ContentKind.Kind.VESSEL:
		button.mouse_entered.connect(_show_entry_tooltip.bind(id))
		button.mouse_exited.connect(_hide_tooltip)
		button.gui_input.connect(_on_entry_gui_input.bind(id, button))
	cell.add_child(button)

	var label := Label.new()
	label.custom_minimum_size = Vector2(96, 0)
	label.text = _entry_name(id) if seen else LOCKED_NAME
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cell.add_child(label)
	return cell


## 魂灵/魂器页已遇见条目：悬停显示与仓库一致的 tooltip
func _show_entry_tooltip(id: StringName) -> void:
	var tip := TooltipWindow.instance
	if not is_instance_valid(tip) or not CollectionDB.is_seen(_kind, id):
		return
	match _kind:
		ContentKind.Kind.SOUL:
			var soul := CollectionDB.get_soul(id)
			if soul == null:
				return
			tip.show_tip(self, TooltipWindow.Layer.ITEM, soul.item_name, SoulTooltip.build(soul, true))
		ContentKind.Kind.VESSEL:
			var vessel := CollectionDB.get_vessel(id)
			if vessel == null:
				return
			# 见闻展示的是模板，没有运行时 contents，网格会显示满格 *
			tip.show_tip(self, TooltipWindow.Layer.ITEM, vessel.item_name, VesselTooltip.build(vessel, true))


func _hide_tooltip() -> void:
	if is_instance_valid(TooltipWindow.instance):
		TooltipWindow.instance.hide_tip(self)


## 右键已遇见魂灵/魂器：放入仓库；怪物条目和未遇见条目不响应
func _on_entry_gui_input(event: InputEvent, id: StringName, button: Button) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_RIGHT or not mouse_event.pressed:
		return
	if not CollectionDB.is_seen(_kind, id):
		return
	var item: ItemData = null
	match _kind:
		ContentKind.Kind.SOUL:
			item = CollectionDB.get_soul(id)
		ContentKind.Kind.VESSEL:
			item = CollectionDB.get_vessel(id)
		_:
			return
	if item == null:
		return
	if not Warehouse.add_item(item):
		push_warning("见闻：%s放入仓库失败「%s」" % [
			"魂灵" if _kind == ContentKind.Kind.SOUL else "魂器", item.item_name,
		])
		return
	_play_add_fly_animation(button, item.icon)


## 从被点条目的图标生成一个临时残影，向右飞出一条抛物线后淡出
func _play_add_fly_animation(button: Button, icon: Texture2D) -> void:
	if icon == null:
		return

	var ghost := TextureRect.new()
	ghost.texture = icon
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.size = Vector2(FLY_GHOST_SIZE, FLY_GHOST_SIZE)
	ghost.pivot_offset = ghost.size * 0.5
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_layer.add_child(ghost)

	var start := button.get_global_rect().get_center() - fly_layer.get_global_rect().position
	var end := Vector2(fly_layer.size.x - FLY_END_MARGIN, start.y)
	# 控制点在起点上方，保证弧线不飞出窗口顶部
	var peak_y := maxf(start.y - FLY_ARC_HEIGHT, FLY_GHOST_SIZE * 0.5)
	var control := Vector2((start.x + end.x) * 0.5, peak_y)
	ghost.position = start - ghost.size * 0.5

	var tween := ghost.create_tween()
	tween.set_parallel(true)
	var place := func (t: float) -> void:
		ghost.position = _quadratic_bezier(start, control, end, t) - ghost.size * 0.5
	tween.tween_method(place, 0.0, 1.0, FLY_DURATION)
	tween.tween_property(ghost, "scale", Vector2(0.5, 0.5), FLY_DURATION)
	tween.tween_property(ghost, "modulate:a", 0.0, FLY_DURATION * 0.3).set_delay(FLY_DURATION * 0.7)
	tween.finished.connect(ghost.queue_free)


## 二次贝塞尔求值：三个点确定一条抛物线
func _quadratic_bezier(start: Vector2, control: Vector2, end: Vector2, t: float) -> Vector2:
	var inv := 1.0 - t
	return inv * inv * start + 2.0 * inv * t * control + t * t * end


func _on_entry_unlocked(kind: int, _id: StringName) -> void:
	if kind == _kind:
		_refresh()


## 读档整体替换已遇见状态后刷新当前页
func _on_state_reloaded() -> void:
	_refresh()


## 关窗时收起 tooltip：tooltip 是独立窗口，不会跟着见闻窗口一起隐藏
func _on_visibility_changed() -> void:
	if not visible:
		_hide_tooltip()
