class_name CollectionWindow
extends BaseWindow
## 见闻：已遇见的怪物与魂灵。
##
## 全量条目来自 CollectionDB（底层是两份 YARD registry）；
## 未遇见的条目也占位显示，只是不暴露名字和图标。
## 魂灵页的已遇见条目：悬停显示 tooltip，右键放入仓库。

const LOCKED_NAME: String = "？？？"
## 仓库窗口展示的容器；右键魂灵直接往这里塞
const WAREHOUSE_CONTAINER: String = "inventory_0"

@onready var monster_button: Button = $Root/VBox/KindRow/MonsterButton
@onready var soul_button: Button = $Root/VBox/KindRow/SoulButton
@onready var entry_grid: GridContainer = $Root/VBox/Body/Scroll/EntryGrid

## 当前分类：CollectionDB.Kind
var _kind: int = CollectionDB.Kind.MONSTER


func _ready() -> void:
	super()
	title = "见闻"
	monster_button.pressed.connect(_select_kind.bind(CollectionDB.Kind.MONSTER))
	soul_button.pressed.connect(_select_kind.bind(CollectionDB.Kind.SOUL))
	CollectionDB.entry_unlocked.connect(_on_entry_unlocked)
	visibility_changed.connect(_on_visibility_changed)
	_select_kind(CollectionDB.Kind.MONSTER)


## 切换怪物 / 魂灵页签
func _select_kind(kind: int) -> void:
	_kind = kind
	monster_button.button_pressed = kind == CollectionDB.Kind.MONSTER
	soul_button.button_pressed = kind == CollectionDB.Kind.SOUL
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
	if _kind == CollectionDB.Kind.MONSTER:
		ids.assign(CollectionDB.get_monster_ids())
	else:
		ids.assign(CollectionDB.get_soul_ids())
	ids.sort_custom(func(a, b): return _entry_name(a) < _entry_name(b))
	return ids


## 排序和条目显示都用它：怪物取 display_name，魂灵取 item_name
func _entry_name(id: StringName) -> String:
	if _kind == CollectionDB.Kind.MONSTER:
		var monster := CollectionDB.get_monster(id)
		return monster.display_name if monster != null else String(id)
	var soul := CollectionDB.get_soul(id)
	return soul.item_name if soul != null else String(id)


func _entry_icon(id: StringName) -> Texture2D:
	if _kind == CollectionDB.Kind.MONSTER:
		var monster := CollectionDB.get_monster(id)
		return monster.icon if monster != null else null
	var soul := CollectionDB.get_soul(id)
	return soul.icon if soul != null else null


func _make_entry_cell(id: StringName) -> Control:
	var seen := CollectionDB.is_seen(_kind, id)
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)

	var button := Button.new()
	button.custom_minimum_size = Vector2(96, 96)
	button.icon = _entry_icon(id)
	button.expand_icon = true
	if not seen:
		button.modulate = Color(0.3, 0.3, 0.3, 1.0)
	elif _kind == CollectionDB.Kind.SOUL:
		button.mouse_entered.connect(_show_soul_tooltip.bind(id))
		button.mouse_exited.connect(_hide_tooltip)
		button.gui_input.connect(_on_entry_gui_input.bind(id))
	cell.add_child(button)

	var label := Label.new()
	label.custom_minimum_size = Vector2(96, 0)
	label.text = _entry_name(id) if seen else LOCKED_NAME
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cell.add_child(label)
	return cell


## 魂灵页已遇见条目：悬停显示与仓库一致的 tooltip
func _show_soul_tooltip(id: StringName) -> void:
	var tip := TooltipWindow.instance
	if _kind != CollectionDB.Kind.SOUL or not is_instance_valid(tip):
		return
	var soul := CollectionDB.get_soul(id)
	if soul == null or not CollectionDB.is_seen(_kind, id):
		return
	tip.show_tip(self, TooltipWindow.Layer.ITEM, soul.item_name, SoulTooltip.build(soul, true))


func _hide_tooltip() -> void:
	if is_instance_valid(TooltipWindow.instance):
		TooltipWindow.instance.hide_tip(self)


## 右键已遇见魂灵：放入仓库；怪物条目和未遇见条目不响应
func _on_entry_gui_input(event: InputEvent, id: StringName) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_RIGHT or not mouse_event.pressed:
		return
	if _kind != CollectionDB.Kind.SOUL or not CollectionDB.is_seen(_kind, id):
		return
	var soul := CollectionDB.get_soul(id)
	if soul == null:
		return
	if not GBIS.add_item(WAREHOUSE_CONTAINER, soul):
		push_warning("见闻：魂灵放入仓库失败「%s」" % soul.item_name)


func _on_entry_unlocked(kind: int, _id: StringName) -> void:
	if kind == _kind:
		_refresh()


## 关窗时收起 tooltip：tooltip 是独立窗口，不会跟着见闻窗口一起隐藏
func _on_visibility_changed() -> void:
	if not visible:
		_hide_tooltip()
