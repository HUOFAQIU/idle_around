## 战斗调试窗口。
##
## 数据来自 CombatTelemetry（事件流 + 快照）和 SoulRuntimeDB（魂灵运行期状态）；
## 本窗口只读，不参与战斗判定。界面全部用代码搭建，避免调试面板的布局散落在场景里。
class_name DebugWindow extends BaseWindow

const REFRESH_INTERVAL: float = 0.1
const SLOW_REFRESH_INTERVAL: float = 0.5
const TIMELINE_MAX_ROWS: int = 2000
const UNITS_MAX_ROWS: int = 100
const PENDING_MAX: int = 2000
const LOG_MAX_LINES: int = 1200
const SOUL_STATUS_ROW := preload("res://Windows/Debug/soul_status_row.gd")

const CATEGORY_NAMES := {
	CombatEvent.BATTLE: "战斗",
	CombatEvent.CAST: "施法",
	CombatEvent.SOUL: "魂灵",
	CombatEvent.TRIGGER: "触发器",
	CombatEvent.EFFECT: "效果",
	CombatEvent.ATTRIBUTE: "属性",
	CombatEvent.TAG: "标签",
	CombatEvent.CUE: "特效",
	CombatEvent.LOG: "日志",
	CombatEvent.SYSTEM: "系统",
}

const TYPE_NAMES := {
	"start": "开始",
	"end": "结束",
	"unit_added": "单位入场",
	"unit_bound": "单位注册",
	"died": "倒下",
	"moved": "移动",
	"enemy_in_range": "进入攻击范围",
	"enemy_out_of_range": "离开攻击范围",
	"drop": "掉落",
	"drop_roll": "掉落判定",
	"attempt": "尝试施法",
	"activate": "激活",
	"blocked": "被拒绝",
	"failed": "失败",
	"release": "多重触发释放",
	"release_empty": "该次释放空放",
	"empty": "空放",
	"targets": "选目标",
	"soul_targets": "选魂灵",
	"cast_start": "开始吟唱",
	"cancelled": "被打断",
	"crit": "暴击",
	"self_crit": "自身效果暴击",
	"projectiles": "发射投射物",
	"projectile_hit": "投射物命中",
	"projectile_miss": "投射物落空",
	"projectiles_finished": "投射物结束",
	"used": "魂灵被使用",
	"ready": "冷却完成",
	"charge": "充能",
	"pending": "入待释放队列",
	"flush_skip": "队列拒绝",
	"status": "魂灵状态",
	"status_end": "魂灵状态结束",
	"fired": "触发",
	"event": "事件",
	"freeze_applied": "冻结广播",
	"applied": "施加",
	"received": "结算",
	"added": "获得",
	"removed": "移除",
	"tick": "周期结算",
	"changed": "变化",
	"count": "层数变化",
	"granted": "授予能力",
	"line": "日志",
}

var _tabs: TabContainer
var _status_label: Label
var _record_check: CheckButton
var _file_check: CheckButton
var _pause_button: Button
var _clear_button: Button
var _export_button: Button
var _importance_option: OptionButton
var _current_run_check: CheckButton
var _follow_check: CheckButton
var _search_edit: LineEdit

var _overview_status: Label
var _soul_rows_box: VBoxContainer
var _overview_recent: RichTextLabel
var _timeline_tree: Tree
var _timeline_detail: RichTextLabel
var _soul_tree: Tree
var _soul_detail: RichTextLabel
var _unit_tree: Tree
var _unit_detail: RichTextLabel
var _watch_button: Button
var _trigger_tree: Tree
var _trigger_detail: RichTextLabel
var _gas_text: RichTextLabel
var _log_text: RichTextLabel
var _max_events_spin: SpinBox
var _detail_global_check: CheckButton
var _unlock_all_check: CheckButton
var _watch_label: Label
var _record_path_label: Label

var _paused: bool = false
## 跟随最新事件：关闭后时间线/日志不再追加，方便查看历史
var _follow_tail: bool = true
var _refresh_accum: float = 0.0
var _slow_refresh_accum: float = 0.0
## 搜索防抖代次：连续输入时只让最后一次重建
var _search_generation: int = 0
var _snapshot: Dictionary = {}
var _selected_unit_id: int = 0
var _selected_unit: BattleUnit
var _unit_by_id: Dictionary = {}
var _soul_rows: Dictionary = {}
var _pending_events: Array[Dictionary] = []
var _timeline_seen_seq: int = 0
var _timeline_selected_seq: int = 0
var _log_line_count: int = 0
var _log_rebuilding: bool = false


func _ready() -> void:
	super()
	title = "调试窗口"
	_build_ui()
	_connect_controls()
	var log_bar := _log_text.get_v_scroll_bar()
	if log_bar != null:
		log_bar.value_changed.connect(_on_log_scroll_changed)
	CombatTelemetry.event_recorded.connect(_on_event_recorded)
	CombatTelemetry.run_started.connect(_on_run_changed)
	CombatTelemetry.run_ended.connect(_on_run_changed)
	_sync_controls()
	_rebuild_timeline()
	_rebuild_log()


func _process(delta: float) -> void:
	if not visible:
		return
	var tab := _tabs.get_current_tab()
	_refresh_accum += delta
	if _refresh_accum >= REFRESH_INTERVAL:
		_refresh_accum = 0.0
		# 快照只服务总览/单位/触发器/GAS 页，其余页签不构建
		if not _paused and (tab == 0 or tab == 3 or tab == 4 or tab == 5):
			_refresh_live()
		_refresh_timeline_incremental()
		_update_status()
	_slow_refresh_accum += delta
	if _slow_refresh_accum >= SLOW_REFRESH_INTERVAL:
		_slow_refresh_accum = 0.0
		if not _paused:
			_refresh_trees()
			_refresh_gas()


func _on_visibility_changed() -> void:
	if visible:
		_refresh_live()
		_refresh_trees()
		_refresh_gas()
		_rebuild_timeline()
		_rebuild_log()
		_sync_controls()


#region UI 搭建
func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var toolbar := HBoxContainer.new()
	toolbar.name = "Toolbar"
	toolbar.add_theme_constant_override("separation", 6)
	vbox.add_child(toolbar)

	_record_check = _make_check(toolbar, "RecordCheck", "录制")
	_file_check = _make_check(toolbar, "FileCheck", "写文件")
	_pause_button = _make_button(toolbar, "PauseButton", "暂停")
	_clear_button = _make_button(toolbar, "ClearButton", "清空")
	_export_button = _make_button(toolbar, "ExportButton", "导出")
	_importance_option = OptionButton.new()
	_importance_option.name = "ImportanceOption"
	_importance_option.add_item("重要+详细", 0)
	_importance_option.add_item("仅重要", 1)
	_importance_option.add_item("仅详细", 2)
	_importance_option.selected = 0
	toolbar.add_child(_importance_option)
	_current_run_check = _make_check(toolbar, "CurrentRunCheck", "本场")
	_current_run_check.button_pressed = true
	_follow_check = _make_check(toolbar, "FollowCheck", "跟随")
	_follow_check.button_pressed = true
	_follow_check.tooltip_text = "打开时时间线跟随最新事件；手动滚动/点选历史或关闭后不再自动滚动"
	_search_edit = LineEdit.new()
	_search_edit.name = "SearchEdit"
	_search_edit.placeholder_text = "搜索单位/魂灵/效果/事件"
	_search_edit.custom_minimum_size = Vector2(160, 0)
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_search_edit)

	_tabs = TabContainer.new()
	_tabs.name = "Tabs"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tabs)

	_build_overview_tab()
	_build_timeline_tab()
	_build_souls_tab()
	_build_units_tab()
	_build_triggers_tab()
	_build_gas_tab()
	_build_log_tab()
	_build_settings_tab()
	_tabs.tab_changed.connect(_on_tab_changed)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.DEBUG_TEXT))
	vbox.add_child(_status_label)


func _build_overview_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "总览"
	tab.add_theme_constant_override("separation", 4)
	_tabs.add_child(tab)

	_overview_status = Label.new()
	_overview_status.name = "Status"
	tab.add_child(_overview_status)

	var scroll := ScrollContainer.new()
	scroll.name = "SoulScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab.add_child(scroll)

	_soul_rows_box = VBoxContainer.new()
	_soul_rows_box.name = "SoulRows"
	_soul_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_soul_rows_box)

	_overview_recent = _make_rich(tab, "Recent", 160)
	_overview_recent.size_flags_vertical = Control.SIZE_SHRINK_END


func _build_timeline_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "时间线"
	_tabs.add_child(tab)
	var split := VSplitContainer.new()
	split.name = "Split"
	split.split_offset = 460
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(split)
	_timeline_tree = _make_tree(split, "Tree", ["时间", "类别", "事件", "来源", "目标", "详情"])
	_timeline_detail = _make_rich(split, "Detail", 190)
	_timeline_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_timeline_tree.item_selected.connect(_on_timeline_selected)
	_timeline_tree.gui_input.connect(_on_timeline_gui_input)


func _build_souls_tab() -> void:
	var tab := VSplitContainer.new()
	tab.name = "魂灵"
	tab.split_offset = 220
	_tabs.add_child(tab)
	_soul_tree = _make_tree(tab, "Tree", ["魂灵", "魂器", "槽位", "冷却", "充能", "状态", "统计"])
	_soul_detail = _make_rich(tab, "Detail", 220)
	_soul_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_soul_tree.item_selected.connect(_on_soul_selected)


func _build_units_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "单位"
	_tabs.add_child(tab)
	var bar := HBoxContainer.new()
	bar.name = "Bar"
	tab.add_child(bar)
	_watch_button = _make_button(bar, "WatchButton", "关注选中单位")
	_watch_button.disabled = true
	var hint := Label.new()
	hint.text = "详细事件只记录关注单位；玩家默认关注。"
	hint.add_theme_color_override("font_color", GameColors.to_color(GameColors.DEBUG_HINT))
	bar.add_child(hint)
	var split := VSplitContainer.new()
	split.name = "Split"
	split.split_offset = 300
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(split)
	_unit_tree = _make_tree(split, "Tree", ["名字", "阵营", "HP", "护盾", "灼烧", "剧毒", "再生", "标签", "状态", "距离"])
	_unit_detail = _make_rich(split, "Detail", 220)
	_unit_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_unit_tree.item_selected.connect(_on_unit_selected)


func _build_triggers_tab() -> void:
	var tab := VSplitContainer.new()
	tab.name = "触发器"
	tab.split_offset = 220
	_tabs.add_child(tab)
	_trigger_tree = _make_tree(tab, "Tree", ["来源", "事件", "范围", "条件", "触发次数", "充能"])
	_trigger_detail = _make_rich(tab, "Detail", 220)
	_trigger_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trigger_tree.item_selected.connect(_on_trigger_selected)


func _build_gas_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "GAS"
	_tabs.add_child(tab)
	_gas_text = _make_rich(tab, "Text", 0)
	_gas_text.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _build_log_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "日志"
	_tabs.add_child(tab)
	_log_text = _make_rich(tab, "Text", 0)
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _build_settings_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "设置"
	tab.add_theme_constant_override("separation", 6)
	_tabs.add_child(tab)

	var max_row := HBoxContainer.new()
	tab.add_child(max_row)
	var max_label := Label.new()
	max_label.text = "事件缓冲上限"
	max_row.add_child(max_label)
	_max_events_spin = SpinBox.new()
	_max_events_spin.name = "MaxEvents"
	_max_events_spin.min_value = 100
	_max_events_spin.max_value = 50000
	_max_events_spin.step = 100
	_max_events_spin.value = CombatTelemetry.max_events
	max_row.add_child(_max_events_spin)

	_detail_global_check = CheckButton.new()
	_detail_global_check.name = "DetailGlobal"
	_detail_global_check.text = "记录所有详细事件（敌人属性/周期 tick 也会进缓冲）"
	tab.add_child(_detail_global_check)

	_unlock_all_check = CheckButton.new()
	_unlock_all_check.name = "UnlockAll"
	_unlock_all_check.text = "见闻全部解锁（测试；只影响显示，不写存档）"
	tab.add_child(_unlock_all_check)

	_watch_label = Label.new()
	_watch_label.name = "WatchLabel"
	tab.add_child(_watch_label)
	_record_path_label = Label.new()
	_record_path_label.name = "RecordPath"
	_record_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(_record_path_label)


func _make_check(parent: Control, node_name: String, text: String) -> CheckButton:
	var check := CheckButton.new()
	check.name = node_name
	check.text = text
	parent.add_child(check)
	return check


func _make_button(parent: Control, node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	parent.add_child(button)
	return button


func _make_tree(parent: Control, node_name: String, columns: Array[String]) -> Tree:
	var tree := Tree.new()
	tree.name = node_name
	tree.columns = columns.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in columns.size():
		tree.set_column_title(i, columns[i])
		tree.set_column_expand(i, true)
		tree.set_column_custom_minimum_width(i, 70)
	parent.add_child(tree)
	return tree


func _make_rich(parent: Control, node_name: String, min_height: float) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.name = node_name
	rich.bbcode_enabled = true
	rich.scroll_active = true
	rich.selection_enabled = true
	if min_height > 0.0:
		rich.custom_minimum_size = Vector2(0, min_height)
	parent.add_child(rich)
	return rich


func _connect_controls() -> void:
	_record_check.toggled.connect(_on_record_toggled)
	_file_check.toggled.connect(_on_file_toggled)
	_pause_button.pressed.connect(_on_pause_pressed)
	_clear_button.pressed.connect(_on_clear_pressed)
	_export_button.pressed.connect(_on_export_pressed)
	_importance_option.item_selected.connect(func(_index: int): _rebuild_timeline())
	_current_run_check.toggled.connect(func(_on: bool): _rebuild_timeline())
	_follow_check.toggled.connect(_on_follow_toggled)
	_search_edit.text_changed.connect(_on_search_changed)
	_watch_button.pressed.connect(_on_watch_pressed)
	_max_events_spin.value_changed.connect(_on_max_events_changed)
	_detail_global_check.toggled.connect(_on_detail_global_toggled)
	_unlock_all_check.toggled.connect(_on_unlock_all_toggled)
	visibility_changed.connect(_on_visibility_changed)


## 搜索框逐字重建 2000 行太贵，200ms 防抖；连续输入只保留最后一次
func _on_search_changed(_text: String) -> void:
	_search_generation += 1
	var generation := _search_generation
	await get_tree().create_timer(0.2).timeout
	if generation != _search_generation or not visible:
		return
	_rebuild_timeline()


func _sync_controls() -> void:
	_record_check.set_pressed_no_signal(CombatTelemetry.enabled)
	_file_check.set_pressed_no_signal(CombatTelemetry.record_to_file)
	_detail_global_check.set_pressed_no_signal(CombatTelemetry.record_detail_globally)
	_unlock_all_check.set_pressed_no_signal(CollectionDB.unlock_all_for_testing)
	_follow_check.set_pressed_no_signal(_follow_tail)
	_max_events_spin.set_value_no_signal(CombatTelemetry.max_events)
	_update_watch_label()
#endregion


#region 工具栏
func _on_record_toggled(on: bool) -> void:
	CombatTelemetry.set_enabled(on)
	_update_status()


func _on_file_toggled(on: bool) -> void:
	CombatTelemetry.set_record_to_file(on)
	_record_path_label.text = "录制文件：%s" % CombatTelemetry.get_record_path()
	_update_status()


func _on_pause_pressed() -> void:
	_paused = not _paused
	_pause_button.text = "继续" if _paused else "暂停"
	if not _paused and _follow_tail:
		# 暂停期间日志没有追加；恢复时从缓冲补齐（查看历史模式保持用户位置）
		_rebuild_log()
	_update_status()


func _on_follow_toggled(on: bool) -> void:
	_set_follow_tail(on)


## 跟随最新：关闭后时间线/日志不再追加，停在当前内容；重新打开时跳回最新。
func _set_follow_tail(on: bool) -> void:
	_follow_tail = on
	if _follow_check != null:
		_follow_check.set_pressed_no_signal(on)
	_pending_events.clear()
	if on:
		_rebuild_timeline()
		_rebuild_log()
	_update_status()


## 鼠标滚轮/触控板滚动时间线时自动停止跟随，方便查看历史
func _on_timeline_gui_input(event: InputEvent) -> void:
	if not _follow_tail:
		return
	var scrolling := false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		scrolling = (
			mouse_event.pressed
			and (
				mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP
				or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN
				or mouse_event.button_index == MOUSE_BUTTON_LEFT
			)
		)
	elif event is InputEventPanGesture:
		scrolling = true
	if scrolling:
		_set_follow_tail(false)


func _on_clear_pressed() -> void:
	CombatTelemetry.clear()
	_pending_events.clear()
	_timeline_seen_seq = 0
	_timeline_selected_seq = 0
	_clear_tree(_timeline_tree)
	_clear_tree(_soul_tree)
	_clear_tree(_unit_tree)
	_clear_tree(_trigger_tree)
	_timeline_detail.text = ""
	_soul_detail.text = ""
	_unit_detail.text = ""
	_trigger_detail.text = ""
	_log_text.clear()
	_log_line_count = 0
	_soul_rows.clear()
	for child in _soul_rows_box.get_children():
		child.queue_free()
	_update_status()


func _on_export_pressed() -> void:
	var path := CombatTelemetry.export_jsonl()
	_status_label.text = "已导出：%s" % path if not path.is_empty() else "导出失败"


func _on_watch_pressed() -> void:
	if _selected_unit != null and is_instance_valid(_selected_unit):
		CombatTelemetry.watch_unit(_selected_unit)
		_update_watch_label()
		_update_status()


func _on_max_events_changed(value: float) -> void:
	CombatTelemetry.max_events = int(value)


func _on_detail_global_toggled(on: bool) -> void:
	CombatTelemetry.record_detail_globally = on


func _on_unlock_all_toggled(on: bool) -> void:
	CollectionDB.set_unlock_all_for_testing(on)
#endregion


#region 事件流
func _on_event_recorded(event: Dictionary) -> void:
	if String(event.get("category", "")) == CombatEvent.LOG:
		_append_log_event(event)
	if not visible:
		return
	_pending_events.append(event)
	while _pending_events.size() > PENDING_MAX:
		_pending_events.pop_front()


func _on_run_changed(_run_id: int) -> void:
	if CombatTelemetry.current_battle == null:
		_unit_by_id.clear()
		_selected_unit = null
		_selected_unit_id = 0
		_watch_button.disabled = true
	_update_status()


func _refresh_timeline_incremental() -> void:
	if _paused:
		return
	if not _follow_tail:
		# 不跟随时不追加、不滚动；重新打开“跟随”会从缓冲重建最新内容
		_pending_events.clear()
		return
	if _pending_events.is_empty():
		return
	for event in _pending_events:
		if int(event.get("seq", 0)) <= _timeline_seen_seq:
			continue
		_timeline_seen_seq = int(event.get("seq", 0))
		if _matches_filter(event):
			_append_timeline_row(event)
	_pending_events.clear()
	_trim_timeline()


func _rebuild_timeline() -> void:
	_clear_tree(_timeline_tree)
	_timeline_seen_seq = 0
	_timeline_selected_seq = 0
	_timeline_detail.text = ""
	for event in CombatTelemetry.query({}, TIMELINE_MAX_ROWS):
		_timeline_seen_seq = int(event.get("seq", 0))
		if _matches_filter(event):
			_append_timeline_row(event, false)
	if _follow_tail:
		_scroll_timeline_to_latest()


func _append_timeline_row(event: Dictionary, scroll: bool = true) -> void:
	var root := _timeline_tree.get_root()
	if root == null:
		root = _timeline_tree.create_item()
	var item := _timeline_tree.create_item(root)
	var color := Color.from_string(
		String(event.get("color", GameColors.TEXT_PRIMARY)),
		GameColors.to_color(GameColors.TEXT_PRIMARY)
	)
	var actor: Dictionary = event.get("actor", {})
	var target: Dictionary = event.get("target", {})
	var detail := _event_detail_text(event)
	item.set_text(0, "%.2fs" % float(event.get("t", 0.0)))
	item.set_text(1, String(CATEGORY_NAMES.get(String(event.get("category", "")), event.get("category", ""))))
	item.set_text(2, String(TYPE_NAMES.get(String(event.get("type", "")), event.get("type", ""))))
	item.set_text(3, String(actor.get("name", "")))
	item.set_text(4, String(target.get("name", "")))
	item.set_text(5, detail)
	for column in range(6):
		item.set_custom_color(column, color)
	item.set_metadata(0, event)
	if int(event.get("seq", 0)) == _timeline_selected_seq:
		item.select(0)
	if scroll and _follow_tail:
		_timeline_tree.scroll_to_item(item)


func _scroll_timeline_to_latest() -> void:
	var root := _timeline_tree.get_root()
	if root == null:
		return
	var count := root.get_child_count()
	if count <= 0:
		return
	var last: TreeItem = root.get_child(count - 1)
	if last != null:
		_timeline_tree.scroll_to_item(last)


func _trim_timeline() -> void:
	var root := _timeline_tree.get_root()
	if root == null:
		return
	while _timeline_tree.get_root().get_child_count() > TIMELINE_MAX_ROWS:
		var first := _timeline_tree.get_root().get_first_child()
		if first == null:
			break
		first.free()


func _on_timeline_selected() -> void:
	var selected := _timeline_tree.get_selected()
	if selected == null:
		return
	var event: Dictionary = selected.get_metadata(0)
	if event.is_empty():
		return
	# 点选历史事件时停止跟随，避免下一帧又被拉回底部
	if _follow_tail:
		_set_follow_tail(false)
	_timeline_selected_seq = int(event.get("seq", 0))
	_timeline_detail.text = _format_event_detail(event)


func _matches_filter(event: Dictionary) -> bool:
	if _current_run_check.button_pressed and CombatTelemetry.current_run_id != 0:
		if int(event.get("run_id", 0)) != CombatTelemetry.current_run_id:
			return false
	var importance := _importance_option.selected
	if importance == 1 and String(event.get("importance", "")) != CombatEvent.IMPORTANT:
		return false
	if importance == 2 and String(event.get("importance", "")) != CombatEvent.DETAIL:
		return false
	var needle := _search_edit.text.strip_edges().to_lower()
	if needle.is_empty():
		return true
	return _event_search_text(event).to_lower().contains(needle)


func _event_search_text(event: Dictionary) -> String:
	var actor: Dictionary = event.get("actor", {})
	var target: Dictionary = event.get("target", {})
	return " ".join([
		String(event.get("category", "")),
		String(event.get("type", "")),
		String(event.get("soul", "")),
		String(event.get("ability", "")),
		String(event.get("effect", "")),
		String(event.get("detail", "")),
		String(actor.get("name", "")),
		String(target.get("name", "")),
	])


func _event_detail_text(event: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["soul", "ability", "effect", "status", "event", "attribute", "detail"]:
		if event.has(key) and not String(event[key]).is_empty():
			parts.append(String(event[key]))
	if event.has("amount"):
		parts.append("x%s" % str(event["amount"]))
	if event.has("health_delta") and not is_zero_approx(float(event["health_delta"])):
		parts.append("HP %+d" % int(event["health_delta"]))
	return " | ".join(parts)


func _format_event_detail(event: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[b]事件 #%d[/b]  %s / %s" % [
		int(event.get("seq", 0)),
		String(CATEGORY_NAMES.get(String(event.get("category", "")), event.get("category", ""))),
		String(TYPE_NAMES.get(String(event.get("type", "")), event.get("type", ""))),
	])
	lines.append("时间：%.2fs  帧：%d  重要度：%s" % [
		float(event.get("t", 0.0)),
		int(event.get("frame", 0)),
		String(event.get("importance", "")),
	])
	for key in event.keys():
		if key in ["seq", "run_id", "frame", "t", "category", "type", "importance", "color"]:
			continue
		lines.append("%s：%s" % [key, str(event[key])])
	var trace_id := int(event.get("trace_id", 0))
	if trace_id > 0:
		lines.append("")
		lines.append("[b]因果链[/b]")
		for linked in CombatTelemetry.get_trace_chain(trace_id):
			var marker := "→" if int(linked.get("seq", 0)) == int(event.get("seq", 0)) else " "
			lines.append("%s #%d %.2fs %s %s" % [
				marker,
				int(linked.get("seq", 0)),
				float(linked.get("t", 0.0)),
				String(TYPE_NAMES.get(String(linked.get("type", "")), linked.get("type", ""))),
				_event_detail_text(linked),
			])
	return "\n".join(lines)
#endregion


#region 实时面板
func _refresh_live() -> void:
	var battle := CombatTelemetry.current_battle
	if battle == null or not is_instance_valid(battle):
		_snapshot = {}
		_overview_status.text = "没有进行中的战斗"
		_clear_soul_rows()
		_overview_recent.text = ""
		return
	_snapshot = CombatSnapshot.build(battle, _selected_unit)
	_unit_by_id.clear()
	for unit in battle.units:
		if unit != null:
			_unit_by_id[unit.get_instance_id()] = unit
	_refresh_overview()
	_refresh_selected_unit_ref()


func _refresh_overview() -> void:
	var player: Dictionary = _snapshot.get("player", {})
	_overview_status.text = "战斗 %.1fs | 敌人 %d | 玩家 HP %.0f/%.0f | 事件 %d | 丢失 %d | FPS %d" % [
		float(_snapshot.get("elapsed", 0.0)),
		int(_snapshot.get("enemy_count", 0)),
		float(player.get("hp", 0.0)),
		float(player.get("max_hp", 0.0)),
		CombatTelemetry.events.size(),
		CombatTelemetry.dropped_events,
		Engine.get_frames_per_second(),
	]
	var runtimes := SoulRuntimeDB.player_runtimes()
	var alive: Dictionary = {}
	for runtime in runtimes:
		alive[runtime.id] = true
		var row: Node = _soul_rows.get(runtime.id)
		if row == null:
			row = SOUL_STATUS_ROW.new()
			_soul_rows_box.add_child(row)
			_soul_rows[runtime.id] = row
		row.bind(runtime)
		row.refresh()
	for id in _soul_rows.keys():
		if not alive.has(id):
			var row: Node = _soul_rows[id]
			row.queue_free()
			_soul_rows.erase(id)
	_overview_recent.text = _format_recent_events()


func _clear_soul_rows() -> void:
	for child in _soul_rows_box.get_children():
		child.queue_free()
	_soul_rows.clear()


func _format_recent_events() -> String:
	var lines: Array[String] = []
	var filter: Dictionary = {"importance": CombatEvent.IMPORTANT}
	if CombatTelemetry.current_run_id != 0:
		filter["run_id"] = CombatTelemetry.current_run_id
	for event in CombatTelemetry.query(filter, 12):
		var actor: Dictionary = event.get("actor", {})
		var target: Dictionary = event.get("target", {})
		var detail := _event_detail_text(event)
		lines.append("[color=%s]%.2fs [%s] %s%s%s[/color]" % [
			String(event.get("color", "#ffffff")),
			float(event.get("t", 0.0)),
			String(CATEGORY_NAMES.get(String(event.get("category", "")), event.get("category", ""))),
			String(actor.get("name", "")),
			(" → " + String(target.get("name", ""))) if not String(target.get("name", "")).is_empty() else "",
			("  " + detail) if not detail.is_empty() else "",
		])
	return "\n".join(lines)


## 只刷新当前页签对应的树，避免每 0.5 秒重建三棵树
func _refresh_trees() -> void:
	match _tabs.get_current_tab():
		2:
			_refresh_soul_tree()
		3:
			_refresh_unit_tree()
		4:
			_refresh_trigger_tree()


func _on_tab_changed(_tab: int) -> void:
	_refresh_live()
	_refresh_trees()
	_refresh_gas()


func _refresh_soul_tree() -> void:
	var selected_id := _selected_runtime_id(_soul_tree)
	_clear_tree(_soul_tree)
	var root := _soul_tree.create_item()
	for runtime in SoulRuntimeDB.player_runtimes():
		var item := _soul_tree.create_item(root)
		var ability := runtime.ability
		item.set_text(0, runtime.display_name())
		item.set_text(1, _part_text(runtime))
		item.set_text(2, str(runtime.slot.column) if runtime.slot != null else "-")
		item.set_text(3, "%.1f/%.1fs" % [ability.charge_seconds(), ability.cooldown] if ability != null else "被动")
		item.set_text(4, "%.0f%%" % (runtime.scanline_progress * 100.0))
		var statuses: Array[String] = []
		if runtime.haste_seconds > 0.0:
			statuses.append("加速")
		if runtime.slow_seconds > 0.0:
			statuses.append("减速")
		if runtime.freeze_seconds > 0.0:
			statuses.append("冻结")
		item.set_text(5, " ".join(statuses))
		item.set_text(6, "激活 %d / 触发 %d" % [
			int(runtime.counter("activations")),
			int(runtime.counter("triggers_fired")),
		])
		item.set_metadata(0, runtime.id)
		if runtime.id == selected_id:
			item.select(0)
			_show_soul_detail(runtime)
	if selected_id == 0 and _soul_tree.get_root() != null:
		var first := _soul_tree.get_root().get_first_child()
		if first != null:
			first.select(0)
			_on_soul_selected()


func _on_soul_selected() -> void:
	var selected := _soul_tree.get_selected()
	if selected == null:
		return
	var runtime_id := int(selected.get_metadata(0))
	for runtime in SoulRuntimeDB.player_runtimes():
		if runtime.id == runtime_id:
			_show_soul_detail(runtime)
			break


func _show_soul_detail(runtime: SoulRuntime) -> void:
	var data := runtime.to_dict()
	var lines: Array[String] = []
	lines.append("[b]%s[/b]  %s  列 %d 宽 %d" % [
		runtime.display_name(),
		_part_text(runtime),
		int(data.get("column", -1)),
		int(data.get("width", 1)),
	])
	lines.append("冷却 %.2fs  充能 %.2fs (%.0f%%)" % [
		float(data.get("cooldown", 0.0)),
		float(data.get("charge_seconds", 0.0)),
		float(data.get("charge_ratio", 0.0)) * 100.0,
	])
	lines.append("加速 %.1fs  减速 %.1fs  冻结 %.1fs  冻结中 %s  施法中 %s  激活锁 %.2fs" % [
		float(data.get("haste", 0.0)),
		float(data.get("slow", 0.0)),
		float(data.get("freeze", 0.0)),
		str(data.get("frozen", false)),
		str(data.get("active", false)),
		float(data.get("activation_lock", 0.0)),
	])
	var contribution := _soul_contribution(runtime.display_name())
	lines.append("")
	lines.append("[b]本场贡献[/b]")
	lines.append("  伤害 %.0f  治疗 %.0f  护盾吸收 %.0f" % [
		float(contribution.get("damage", 0.0)),
		float(contribution.get("heal", 0.0)),
		float(contribution.get("shield", 0.0)),
	])
	lines.append("  灼烧 %.0f  剧毒 %.0f  再生 %.0f" % [
		float(contribution.get("burn", 0.0)),
		float(contribution.get("poison", 0.0)),
		float(contribution.get("regen", 0.0)),
	])
	lines.append("")
	lines.append("[b]统计[/b]")
	var counters: Dictionary = data.get("counters", {})
	for key in counters:
		lines.append("  %s：%s" % [key, str(counters[key])])
	lines.append("")
	lines.append("[b]触发器[/b]")
	var triggers: Array = data.get("triggers", [])
	if triggers.is_empty():
		lines.append("  （无）")
	for trigger in triggers:
		lines.append("  %s  次数=%d  已用=%s  %s" % [
			String(trigger.get("event", "")),
			int(trigger.get("run_count", 0)),
			str(trigger.get("fired", false)),
			String(trigger.get("name", "")),
		])
	_soul_detail.text = "\n".join(lines)


## 从事件流汇总一颗魂灵本场的伤害/治疗/状态贡献；
## 通过 event.soul 或 trace_cause 里的来源名归属。
func _soul_contribution(soul_name: String) -> Dictionary:
	var result := {
		"damage": 0.0, "heal": 0.0, "shield": 0.0,
		"burn": 0.0, "poison": 0.0, "regen": 0.0, "events": 0,
	}
	if soul_name.is_empty():
		return result
	var filter: Dictionary = {}
	if CombatTelemetry.current_run_id != 0:
		filter["run_id"] = CombatTelemetry.current_run_id
	for event in CombatTelemetry.query(filter, 0):
		if not _event_belongs_to_soul(event, soul_name):
			continue
		result["events"] = int(result["events"]) + 1
		if String(event.get("category", "")) != CombatEvent.EFFECT:
			continue
		var health_delta := float(event.get("health_delta", 0.0))
		var shield_delta := float(event.get("shield_delta", 0.0))
		if shield_delta < 0.0:
			result["shield"] = float(result["shield"]) - shield_delta
		if health_delta < 0.0:
			result["damage"] = float(result["damage"]) - health_delta
			match String(event.get("effect", "")):
				"灼烧":
					result["burn"] = float(result["burn"]) - health_delta
				"剧毒":
					result["poison"] = float(result["poison"]) - health_delta
		elif health_delta > 0.0:
			result["heal"] = float(result["heal"]) + health_delta
			if String(event.get("effect", "")) == "生命再生":
				result["regen"] = float(result["regen"]) + health_delta
	return result


func _event_belongs_to_soul(event: Dictionary, soul_name: String) -> bool:
	if String(event.get("soul", "")) == soul_name:
		return true
	if String(event.get("ability", "")) == soul_name:
		return true
	var cause := String(event.get("trace_cause", ""))
	return cause.contains("cast:" + soul_name) or cause.contains("trigger:" + soul_name)


func _refresh_unit_tree() -> void:
	var selected_id := _selected_unit_id
	_clear_tree(_unit_tree)
	var root := _unit_tree.create_item()
	var rows: Array = []
	for enemy in _snapshot.get("enemies", []):
		rows.append(enemy)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance_to_player", INF)) < float(b.get("distance_to_player", INF)))
	var player: Dictionary = _snapshot.get("player", {})
	if not player.is_empty():
		_add_unit_row(root, player)
	for i in mini(rows.size(), UNITS_MAX_ROWS):
		_add_unit_row(root, rows[i])
	if rows.size() > UNITS_MAX_ROWS:
		var note := _unit_tree.create_item(root)
		note.set_text(0, "…… 还有 %d 个敌人未显示" % (rows.size() - UNITS_MAX_ROWS))
		note.set_selectable(0, false)
	if selected_id != 0:
		for item in root.get_children():
			if int(item.get_metadata(0)) == selected_id:
				item.select(0)
				break
	else:
		var first := root.get_first_child()
		if first != null:
			first.select(0)
			_on_unit_selected()


func _add_unit_row(root: TreeItem, unit_data: Dictionary) -> void:
	var item := _unit_tree.create_item(root)
	item.set_text(0, String(unit_data.get("name", "?")))
	item.set_text(1, String(unit_data.get("team", "")))
	item.set_text(2, "%.0f/%.0f" % [float(unit_data.get("hp", 0.0)), float(unit_data.get("max_hp", 0.0))])
	item.set_text(3, "%.0f" % float(unit_data.get("shield", 0.0)))
	item.set_text(4, "%.0f" % float(unit_data.get("burn", 0.0)))
	item.set_text(5, "%.0f" % float(unit_data.get("poison", 0.0)))
	item.set_text(6, "%.0f" % float(unit_data.get("regen", 0.0)))
	item.set_text(7, str(unit_data.get("tags_count", 0)))
	var status := []
	if bool(unit_data.get("dead", false)):
		status.append("死亡")
	if bool(unit_data.get("frozen", false)):
		status.append("冻结")
	if bool(unit_data.get("in_attack_range", false)):
		status.append("范围内")
	item.set_text(8, " ".join(status))
	item.set_text(9, "%.0f" % float(unit_data.get("distance_to_player", 0.0)))
	item.set_metadata(0, int(unit_data.get("id", 0)))
	if int(unit_data.get("id", 0)) == CombatTelemetry.watch_unit_id:
		item.set_custom_color(0, GameColors.to_color(GameColors.DEBUG_HIGHLIGHT))


func _on_unit_selected() -> void:
	var selected := _unit_tree.get_selected()
	if selected == null:
		return
	_selected_unit_id = int(selected.get_metadata(0))
	_selected_unit = _unit_by_id.get(_selected_unit_id)
	_watch_button.disabled = _selected_unit == null
	_refresh_selected_unit_ref()
	if _selected_unit != null:
		var data: Dictionary = _snapshot.get("selected", {})
		if data.is_empty():
			data = CombatSnapshot.unit_detail(_selected_unit, CombatTelemetry.current_battle)
		_unit_detail.text = _format_unit_detail(data)


func _refresh_selected_unit_ref() -> void:
	if _selected_unit == null or not is_instance_valid(_selected_unit):
		_selected_unit = _unit_by_id.get(_selected_unit_id)
	if _selected_unit == null:
		return
	var data: Dictionary = _snapshot.get("selected", {})
	if data.is_empty():
		data = CombatSnapshot.unit_detail(_selected_unit, CombatTelemetry.current_battle)
	_unit_detail.text = _format_unit_detail(data)


func _format_unit_detail(data: Dictionary) -> String:
	if data.is_empty():
		return ""
	var lines: Array[String] = []
	lines.append("[b]%s[/b]  %s  HP %.0f/%.0f  护盾 %.0f  灼烧 %.0f  剧毒 %.0f  再生 %.0f" % [
		String(data.get("name", "?")),
		String(data.get("team", "")),
		float(data.get("hp", 0.0)),
		float(data.get("max_hp", 0.0)),
		float(data.get("shield", 0.0)),
		float(data.get("burn", 0.0)),
		float(data.get("poison", 0.0)),
		float(data.get("regen", 0.0)),
	])
	lines.append("")
	lines.append("[b]属性[/b]")
	var attributes: Dictionary = data.get("attributes", {})
	for key in attributes:
		var attr: Dictionary = attributes[key]
		lines.append("  %s：%.1f / base %.1f" % [key, float(attr.get("current", 0.0)), float(attr.get("base", 0.0))])
	lines.append("")
	lines.append("[b]标签[/b]")
	var tags: Dictionary = data.get("tags", {})
	for key in tags:
		lines.append("  %s x%d" % [key, int(tags[key])])
	lines.append("")
	lines.append("[b]效果[/b]")
	var effects: Array = data.get("effects", [])
	if effects.is_empty():
		lines.append("  （无）")
	for effect in effects:
		lines.append("  %s  %s  剩余 %.2f  层 %d  来源 %s%s" % [
			String(effect.get("name", "")),
			String(effect.get("policy", "")),
			float(effect.get("remaining", 0.0)),
			int(effect.get("stacks", 1)),
			String(effect.get("source", "")),
			"  [已抑制]" if bool(effect.get("suppressed", false)) else "",
		])
	lines.append("")
	lines.append("[b]能力[/b]")
	var abilities: Array = data.get("abilities", [])
	for ability in abilities:
		lines.append("  %s  %s  充能 %.0f%%  激活=%s" % [
			String(ability.get("name", "")),
			String(ability.get("tag", "")),
			float(ability.get("charge_ratio", 0.0)) * 100.0,
			str(ability.get("active", false)),
		])
	lines.append("")
	lines.append("[b]魂灵[/b]")
	var loadout: Array = data.get("loadout", [])
	for runtime in loadout:
		lines.append("  %s  %s  充能 %.0f%%" % [
			String(runtime.get("name", "")),
			String(runtime.get("vessel", "")),
			float(runtime.get("charge_ratio", 0.0)) * 100.0,
		])
	return "\n".join(lines)


func _refresh_trigger_tree() -> void:
	var selected_source := ""
	var selected := _trigger_tree.get_selected()
	if selected != null:
		selected_source = String(selected.get_metadata(0).get("source", ""))
	_clear_tree(_trigger_tree)
	var root := _trigger_tree.create_item()
	var unit := _selected_unit
	if unit == null or not is_instance_valid(unit):
		unit = CombatTelemetry.current_battle.player if CombatTelemetry.current_battle != null else null
	if unit == null:
		return
	for trigger in CombatSnapshot.triggers(unit):
		var item := _trigger_tree.create_item(root)
		item.set_text(0, String(trigger.get("source", "")))
		item.set_text(1, String(trigger.get("event_label", trigger.get("event", ""))))
		item.set_text(2, String(trigger.get("target_scope", "")))
		item.set_text(3, _trigger_condition_text(trigger))
		var run_count := int(trigger.get("run_count", 0))
		var once_mark := "（每场一次）" if bool(trigger.get("once_per_battle", false)) else ""
		item.set_text(4, "%d%s" % [run_count, once_mark])
		item.set_text(5, "%.1fs" % float(trigger.get("charge_source_seconds", 0.0)))
		item.set_metadata(0, trigger)
		if String(trigger.get("source", "")) == selected_source:
			item.select(0)
	if selected_source.is_empty():
		var first := root.get_first_child()
		if first != null:
			first.select(0)
			_on_trigger_selected()


func _trigger_condition_text(trigger: Dictionary) -> String:
	var parts: Array[String] = []
	if float(trigger.get("threshold_ratio", 0.0)) > 0.0 and String(trigger.get("event", "")) == "Event.Health.BelowPercent":
		parts.append("HP < %.0f%%" % (float(trigger.get("threshold_ratio", 0.0)) * 100.0))
	if bool(trigger.get("once_per_battle", false)):
		parts.append("每场一次")
	if bool(trigger.get("require_adjacent", false)):
		parts.append("需相邻")
	var required: Array = trigger.get("required_soul_types", [])
	if not required.is_empty():
		parts.append("类型 " + "、".join(required))
	return " ".join(parts)


func _on_trigger_selected() -> void:
	var selected := _trigger_tree.get_selected()
	if selected == null:
		return
	var trigger: Dictionary = selected.get_metadata(0)
	var lines: Array[String] = []
	for key in trigger:
		lines.append("%s：%s" % [key, str(trigger[key])])
	_trigger_detail.text = "\n".join(lines)


func _refresh_gas() -> void:
	if _tabs.get_current_tab() != 5:
		return
	var lines: Array[String] = []
	lines.append("[b]GAS 状态[/b]")
	var battle := CombatTelemetry.current_battle
	if battle != null and battle.player != null:
		var player_tags: Dictionary = _snapshot.get("player", {}).get("tags", {})
		lines.append("玩家标签：%s" % (", ".join(player_tags.keys()) if not player_tags.is_empty() else "（无）"))
	var cue_tags: Array = []
	if GameplayCueManager != null:
		cue_tags.assign(GameplayCueManager._cue_scenes.keys())
	lines.append("已注册 Cue：%s" % (", ".join(cue_tags) if not cue_tags.is_empty() else "（无）"))
	lines.append("")
	lines.append("[b]最近激活失败[/b]")
	var run_filter: Dictionary = {}
	if CombatTelemetry.current_run_id != 0:
		run_filter["run_id"] = CombatTelemetry.current_run_id
	var blocked_filter := run_filter.duplicate()
	blocked_filter["category"] = CombatEvent.CAST
	blocked_filter["type"] = "blocked"
	var blocked := CombatTelemetry.query(blocked_filter, 10)
	if blocked.is_empty():
		lines.append("（无）")
	for event in blocked:
		lines.append("%.2fs %s  %s  %s" % [
			float(event.get("t", 0.0)),
			String((event.get("actor", {}) as Dictionary).get("name", "")),
			String(event.get("ability", "")),
			String(event.get("reason", "")),
		])
	lines.append("")
	lines.append("[b]最近 GAS 事件[/b]")
	var gas_filter := run_filter.duplicate()
	gas_filter["category"] = CombatEvent.TRIGGER
	gas_filter["type"] = "event"
	for event in CombatTelemetry.query(gas_filter, 10):
		lines.append("%.2fs %s  %s" % [
			float(event.get("t", 0.0)),
			String(event.get("event", "")),
			String(event.get("detail", "")),
		])
	_gas_text.text = "\n".join(lines)
#endregion


#region 日志
func _append_log_event(event: Dictionary) -> void:
	if not visible or _paused or not _follow_tail:
		return
	_log_text.append_text("[color=%s]%s[/color]\n" % [
		String(event.get("color", "white")),
		String(event.get("text", "")),
	])
	_log_line_count += 1
	if _log_line_count > LOG_MAX_LINES:
		_rebuild_log()
	else:
		_log_text.scroll_to_line(_log_text.get_line_count())


func _rebuild_log() -> void:
	_log_rebuilding = true
	_log_text.clear()
	_log_line_count = 0
	for event in CombatTelemetry.query({"category": CombatEvent.LOG}, 800):
		_log_text.append_text("[color=%s]%s[/color]\n" % [
			String(event.get("color", "white")),
			String(event.get("text", "")),
		])
		_log_line_count += 1
	if _follow_tail and _log_line_count > 0:
		_log_text.scroll_to_line(_log_text.get_line_count())
	_log_rebuilding = false


## 日志被用户向上滚动时，自动停止跟随（与时间线共用“跟随”开关）
func _on_log_scroll_changed(value: float) -> void:
	if _log_rebuilding or not _follow_tail:
		return
	var bar := _log_text.get_v_scroll_bar()
	if bar != null and value < bar.max_value - 1.0:
		_set_follow_tail(false)
#endregion


#region 状态 / 工具
func _update_status() -> void:
	var stats := CombatTelemetry.get_stats()
	var watch_name := "无"
	if CombatTelemetry.watch_unit_id != 0:
		for id in _unit_by_id:
			var unit: BattleUnit = _unit_by_id[id]
			if int(id) == CombatTelemetry.watch_unit_id and is_instance_valid(unit):
				watch_name = String(unit.unit_name)
				break
	_status_label.text = "事件 %d/%d | 丢失 %d | 场次 %d | 关注 %s | FPS %d | %s" % [
		int(stats.get("events", 0)),
		int(stats.get("max_events", 0)),
		int(stats.get("dropped_events", 0)),
		int(stats.get("run_id", 0)),
		watch_name,
		Engine.get_frames_per_second(),
		"已暂停" if _paused else ("跟随最新" if _follow_tail else "查看历史"),
	]
	_update_watch_label()


func _update_watch_label() -> void:
	if _watch_label == null:
		return
	var watch_name := "无"
	for id in _unit_by_id:
		var unit: BattleUnit = _unit_by_id[id]
		if int(id) == CombatTelemetry.watch_unit_id and is_instance_valid(unit):
			watch_name = String(unit.unit_name)
			break
	_watch_label.text = "当前关注单位：%s" % watch_name
	_record_path_label.text = "录制文件：%s" % (
		CombatTelemetry.get_record_path() if not CombatTelemetry.get_record_path().is_empty() else "未开启"
	)


func _clear_tree(tree: Tree) -> void:
	tree.clear()


func _selected_runtime_id(tree: Tree) -> int:
	var selected := tree.get_selected()
	return int(selected.get_metadata(0)) if selected != null else 0


func _part_text(runtime: SoulRuntime) -> String:
	if runtime == null:
		return ""
	return runtime.vessel_name()
#endregion
