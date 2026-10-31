class_name CollectionWindow
extends BaseWindow
## 见闻：已遇见的怪物与魂灵。
##
## 全量条目来自 CollectionDB（底层是两份 YARD registry）；
## 未遇见的条目也占位显示，只是不暴露名字、图标和详情。

const LOCKED_NAME: String = "？？？"
const PART_NAMES := {
	"ANY": "不限部位",
	"HEADSOUL": "头部",
	"TORSOSOUL": "身体",
	"ARMSSOUL": "手部",
	"LEGSSOUL": "腿部",
}
## 仓库窗口展示的容器；「放入仓库」直接往这里塞
const WAREHOUSE_CONTAINER: String = "inventory_0"

@onready var monster_button: Button = $Root/VBox/KindRow/MonsterButton
@onready var soul_button: Button = $Root/VBox/KindRow/SoulButton
@onready var entry_grid: GridContainer = $Root/VBox/Body/Scroll/EntryGrid
@onready var detail_icon: TextureRect = $Root/VBox/Body/DetailPanel/DetailMargin/DetailBox/DetailIcon
@onready var detail_name: Label = $Root/VBox/Body/DetailPanel/DetailMargin/DetailBox/DetailName
@onready var detail_meta: Label = $Root/VBox/Body/DetailPanel/DetailMargin/DetailBox/DetailMeta
@onready var detail_text: RichTextLabel = $Root/VBox/Body/DetailPanel/DetailMargin/DetailBox/DetailText
@onready var add_to_inventory_button: Button = $Root/VBox/Body/DetailPanel/DetailMargin/DetailBox/AddToInventoryButton

## 当前分类：CollectionDB.Kind
var _kind: int = CollectionDB.Kind.MONSTER
## 当前详情条目；刷新时如果它还在，就保持选中
var _selected_id: StringName = &""


func _ready() -> void:
	super()
	title = "见闻"
	monster_button.pressed.connect(_select_kind.bind(CollectionDB.Kind.MONSTER))
	soul_button.pressed.connect(_select_kind.bind(CollectionDB.Kind.SOUL))
	CollectionDB.entry_unlocked.connect(_on_entry_unlocked)
	add_to_inventory_button.pressed.connect(_on_add_to_inventory_pressed)
	_select_kind(CollectionDB.Kind.MONSTER)


## 切换怪物 / 魂灵页签
func _select_kind(kind: int) -> void:
	_kind = kind
	monster_button.button_pressed = kind == CollectionDB.Kind.MONSTER
	soul_button.button_pressed = kind == CollectionDB.Kind.SOUL
	_selected_id = &""
	_refresh()


func _refresh() -> void:
	for child in entry_grid.get_children():
		entry_grid.remove_child(child)
		child.queue_free()

	var ids := _sorted_ids()
	for id in ids:
		entry_grid.add_child(_make_entry_cell(id))

	if ids.is_empty():
		_show_empty_detail()
		return
	if not ids.has(_selected_id):
		# 默认选第一颗已遇见的；一颗都没有就选第一个占位
		_selected_id = ids[0]
		for id in ids:
			if CollectionDB.is_seen(_kind, id):
				_selected_id = id
				break
	_show_detail(_selected_id)


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
	button.pressed.connect(_show_detail.bind(id))
	cell.add_child(button)

	var label := Label.new()
	label.custom_minimum_size = Vector2(96, 0)
	label.text = _entry_name(id) if seen else LOCKED_NAME
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cell.add_child(label)
	return cell


func _show_detail(id: StringName) -> void:
	_selected_id = id
	if not CollectionDB.is_seen(_kind, id):
		_show_locked_detail()
		return
	if _kind == CollectionDB.Kind.MONSTER:
		_show_monster_detail(id)
	else:
		_show_soul_detail(id)


func _show_monster_detail(id: StringName) -> void:
	add_to_inventory_button.visible = false
	var monster := CollectionDB.get_monster(id)
	if monster == null:
		return
	detail_icon.texture = monster.icon
	detail_icon.visible = true
	detail_name.text = monster.display_name
	detail_meta.text = "生命上限：%.0f" % monster.max_health

	var lines := PackedStringArray()
	lines.append(monster.description if not monster.description.is_empty() else "暂无记载。")
	if not monster.soul_entries.is_empty():
		lines.append("\n[b]携带魂灵（可掉落）[/b]")
		for entry in monster.soul_entries:
			if entry == null or entry.soul == null:
				continue
			var part := entry.part()
			var part_name: String = PART_NAMES.get(part, part)
			lines.append("· %s：%s（%d%%）"
				% [part_name, entry.soul.item_name, roundi(entry.drop_chance * 100.0)])
	detail_text.text = "\n".join(lines)


func _show_soul_detail(id: StringName) -> void:
	var soul := CollectionDB.get_soul(id)
	add_to_inventory_button.visible = soul != null
	if soul == null:
		return
	detail_icon.texture = soul.icon
	detail_icon.visible = true
	detail_name.text = soul.item_name
	detail_meta.text = PART_NAMES.get(soul.equip_part, soul.equip_part)

	var lines := PackedStringArray()
	if not soul.description.is_empty():
		lines.append(soul.description)

	var passive := soul as PassiveSoulData
	if passive != null:
		lines.append("\n[b]被动魂灵[/b]")
		if not passive.passive_effects.is_empty():
			lines.append("· 属性效果 ×%d" % passive.passive_effects.size())
		if not passive.triggers.is_empty():
			lines.append("· 触发效果 ×%d" % passive.triggers.size())
		if soul.description.is_empty() and passive.passive_effects.is_empty() and passive.triggers.is_empty():
			lines.append("暂无记载。")
	elif soul.skill != null:
		lines.append("\n[b]主动技能[/b]")
		if not soul.skill.description.is_empty():
			lines.append(soul.skill.description)
		elif soul.description.is_empty():
			lines.append("暂无记载。")
		if soul.skill.cooldown_effect != null:
			lines.append("冷却：%.1f 秒" % soul.skill.cooldown_effect.duration)
	else:
		lines.append("\n[b]未配置技能[/b]")
		if soul.description.is_empty():
			lines.append("暂无记载。")
	detail_text.text = "\n".join(lines)


func _show_locked_detail() -> void:
	add_to_inventory_button.visible = false
	detail_icon.texture = null
	detail_icon.visible = false
	detail_name.text = LOCKED_NAME
	detail_meta.text = "尚未遇见"
	detail_text.text = (
		"在战斗中遇见后解锁。"
		if _kind == CollectionDB.Kind.MONSTER
		else "获得这颗魂灵后解锁。"
	)


func _show_empty_detail() -> void:
	add_to_inventory_button.visible = false
	detail_icon.texture = null
	detail_icon.visible = false
	detail_name.text = "暂无条目"
	detail_meta.text = ""
	detail_text.text = "图鉴里还没有可显示的条目。"


func _on_entry_unlocked(kind: int, _id: StringName) -> void:
	if kind == _kind:
		_refresh()


func _on_add_to_inventory_pressed() -> void:
	var soul := CollectionDB.get_soul(_selected_id)
	if soul == null:
		return
	if not GBIS.add_item(WAREHOUSE_CONTAINER, soul):
		push_warning("见闻：魂灵放入仓库失败「%s」" % soul.item_name)
