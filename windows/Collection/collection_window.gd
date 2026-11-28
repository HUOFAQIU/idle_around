class_name CollectionWindow
extends BaseWindow

const LOCKED_NAME: String = "？？？"

@onready var monster_button: Button = $Root/VBox/KindRow/MonsterButton
@onready var soul_button: Button = $Root/VBox/KindRow/SoulButton
@onready var vessel_button: Button = $Root/VBox/KindRow/VesselButton
@onready var entry_grid: GridContainer = $Root/VBox/Body/Scroll/EntryGrid
@onready var hint_label: Label = $Root/VBox/HintLabel

var _kind: int = ContentKind.Kind.MONSTER
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


func _select_kind(kind: int) -> void:
	_kind = kind
	monster_button.button_pressed = kind == ContentKind.Kind.MONSTER
	soul_button.button_pressed = kind == ContentKind.Kind.SOUL
	vessel_button.button_pressed = kind == ContentKind.Kind.VESSEL
	_update_hint()
	_refresh()


func _update_hint() -> void:
	match _kind:
		ContentKind.Kind.MONSTER:
			hint_label.text = "怪物：首次刷出即解锁"
		ContentKind.Kind.SOUL:
			hint_label.text = "魂灵：首次进入背包即解锁"
		ContentKind.Kind.VESSEL:
			hint_label.text = "魂器：首次进入任意容器即解锁"


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
			ids.assign(ModLoader.get_monster_ids())
		ContentKind.Kind.SOUL:
			ids.assign(ModLoader.get_soul_ids())
		ContentKind.Kind.VESSEL:
			ids.assign(ModLoader.get_vessel_ids())
	ids.sort_custom(func(a, b): return _entry_name(a) < _entry_name(b))
	return ids


func _entry_name(id: StringName) -> String:
	match _kind:
		ContentKind.Kind.MONSTER:
			var monster := ModLoader.get_monster(id)
			return monster.display_name if monster != null else String(id)
		ContentKind.Kind.SOUL:
			var soul := ModLoader.get_soul(id)
			return soul.item_name if soul != null else String(id)
		ContentKind.Kind.VESSEL:
			var vessel := ModLoader.get_vessel(id)
			return vessel.item_name if vessel != null else String(id)
	return String(id)


func _entry_icon(id: StringName) -> Texture2D:
	match _kind:
		ContentKind.Kind.MONSTER:
			var monster := ModLoader.get_monster(id)
			return monster.icon if monster != null else null
		ContentKind.Kind.SOUL:
			var soul := ModLoader.get_soul(id)
			return soul.icon if soul != null else null
		ContentKind.Kind.VESSEL:
			var vessel := ModLoader.get_vessel(id)
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
	cell.add_child(button)

	var label := Label.new()
	label.custom_minimum_size = Vector2(96, 0)
	label.text = _entry_name(id) if seen else LOCKED_NAME
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cell.add_child(label)
	return cell


func _show_entry_tooltip(id: StringName) -> void:
	if not CollectionDB.is_seen(_kind, id):
		return
	match _kind:
		ContentKind.Kind.SOUL:
			var soul := ModLoader.get_soul(id)
			if soul == null:
				return
			TooltipService.show_tip(
				self,
				TooltipService.Layer.ITEM,
				soul.item_name,
				SoulTooltip.build(soul, TooltipText.Format.PLAIN)
			)
		ContentKind.Kind.VESSEL:
			var vessel := ModLoader.get_vessel(id)
			if vessel == null:
				return
			TooltipService.show_tip(
				self,
				TooltipService.Layer.ITEM,
				vessel.item_name,
				VesselTooltip.build(vessel, TooltipText.Format.PLAIN)
			)


func _hide_tooltip() -> void:
	TooltipService.hide_tip(self)


func _on_entry_unlocked(kind: int, _id: StringName) -> void:
	if kind == _kind:
		_refresh()


func _on_state_reloaded() -> void:
	_refresh()


func _on_visibility_changed() -> void:
	if not visible:
		_hide_tooltip()
