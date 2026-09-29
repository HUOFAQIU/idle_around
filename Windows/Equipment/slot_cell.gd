class_name SlotCell
extends Panel

## 装备面板里的一行：上面写部位名，左边是装备槽，右边是魂灵区。
## 这一行自己的事儿都归它自己管——挂装备和魂灵的视图、hover 提示、拖拽起落；
## equipment_panel.gd 只管「哪个部位装了哪件」和往哪一行丢。

## 跟仓库共用同一格
const CELL_SIZE : int = InventoryItem.CELL_SIZE

## 魂灵区的格线
const COLOR_SOUL_LINE := Color(0.24, 0.26, 0.31)
const COLOR_HOVER := Color(1.0, 1.0, 1.0, 0.45)
## 冷却：底下填一层半透明黄 + 顶上一条亮线
const COLOR_CD_FILL := Color(1.0, 0.85, 0.35, 0.18)
const COLOR_CD_LINE := Color(1.0, 0.85, 0.35, 0.85)
## 落点框：放得下 / 放不下（跟仓库一个颜色）
const COLOR_DROP_OK := Color(0.45, 0.95, 0.55, 0.9)
const COLOR_DROP_BAD := Color(0.95, 0.35, 0.35, 0.9)

## 魂灵提示框（这一行只 hover 得到魂灵，装备那个提示框是仓库用的）
const TOOLTIP_SCENE : PackedScene = preload("res://Kits/Tooltip/soul_tooltip.tscn")

## 扫描线从下走到顶要多久（秒）。魂灵身上不再带时长，节奏归面板定
@export var cooldown_seconds : float = 2.0

## 这一格空了，请把原来那件接走（被顶下来、或者右键卸下来都走这儿；窗口负责丢进仓库临时页）
signal equipment_removed(equipment: Equipment)

## 这一行是哪个部位，面板按顺序填
var part : Equipment.Part = Equipment.Part.WEAPON
## 现在装着的装备
var equipment : Equipment = null

var _hover_soul : Soul = null
## 正拖着魂灵时记着它原来在哪：[装备, 那一格]；没在拖就是空的
var _drag_back : Array = []

## 槽里那件装备的视图（一次只有一个）
var _equipment_view : ItemView = null
## 魂灵区里每颗魂灵一个视图
var _soul_views : Array[ItemView] = []
## 铺在魂灵区上的一层，画格线 / 冷却 / hover 框 / 落点框。
## 得压在 _soul_views 上面：视图是子节点，父节点自己 `_draw()` 的东西都在它们底下
var _overlay : Control
var _tooltip : SoulTooltip

@onready var _label : Label = $SlotLabel
@onready var _equipment_slot : Control = $HBoxContainer/EquipmentSlot
@onready var _soul_panel : Panel = $HBoxContainer/SoulPanel


func _ready() -> void:
	_equipment_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	_equipment_slot.gui_input.connect(_on_slot_input)
	_soul_panel.gui_input.connect(_on_soul_input)
	_soul_panel.mouse_exited.connect(_on_soul_exited)
	# 格线归面板自己画：父节点 `_draw()` 的东西在子节点底下，正好被魂灵压住
	_soul_panel.draw.connect(_draw_soul_lines)

	_build_overlay()
	# 松手那一下也得重画：不然落点框会留在原地
	GameGlobal.drag_ended.connect(_refresh_overlay)
	_sync_views()


## 面板按顺序喊一声：你是哪个部位
func setup(p_part: Equipment.Part) -> void:
	part = p_part
	_label.text = Equipment.PART_NAMES[part]
	_refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	# 手上拖着魂灵：跟住鼠标，松手就放下
	if _drag_back.size() == 2:
		_refresh_overlay()
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_finish_soul_drag(GameGlobal.mouse_in_window_pos(get_window()))
			return

	# 冷却推进：扫描线从下走到顶，到顶就「放技能」然后从头开始
	# （现在只是视觉，不真的造成伤害）
	if equipment:
		var ticking := false
		for soul in equipment.souls:
			soul.cd_progress += delta / maxf(cooldown_seconds, 0.01)
			if soul.cd_progress >= 1.0:
				soul.cd_progress = 0.0
			ticking = true
		if ticking:
			_refresh_overlay()

	# 别人拖着东西路过：也得跟着重画，不然看不见落点框
	if GameGlobal.dragged_item:
		_refresh_overlay()


# ---------------------------------------------------------------- 装备

## 装上一件；原来那件被换下来就发信号
func equip(new_equipment: Equipment) -> Equipment:
	var old := equipment
	equipment = new_equipment
	_refresh()
	if old:
		equipment_removed.emit(old)
	return old


## 卸下：这一格清空，那件连它的魂灵交给面板（最终进仓库临时页）
func unequip() -> Equipment:
	if equipment == null:
		return null
	var old := equipment
	equipment = null
	_refresh()
	equipment_removed.emit(old)
	return old


# 装备槽上点右键 = 卸下
func _on_slot_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_RIGHT:
		return
	# 手上正拖着东西就先别卸，免得两件事抢同一件
	if GameGlobal.dragged_item != null:
		return
	unequip()


## 别人松手时问这一行：这个落点你要不要（坐标是全局的）。
## 只收魂灵：装备不能拖进来，换装一律走仓库里的右键（`equipment_panel.equip()`）。
## 判定放得比较宽：落在**这一行**上就算（部位名、装备槽上都收），落点再夹进魂灵区——
## 往右拖过头一点松手也装得上，不用像素级对准。
func accept_at(mouse_global: Vector2, item: InventoryItem) -> bool:
	if not (item is Soul) or equipment == null:
		return false
	if not get_global_rect().has_point(mouse_global):
		return false

	var soul := item as Soul
	if not equipment.place_soul(soul, _drop_cell(_to_soul_local(mouse_global), soul)):
		return false
	_refresh()
	return true


# ---------------------------------------------------------------- 魂灵：拿起 / 放下 / 挪位置

func _on_soul_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		_start_soul_drag(button.position)
		return

	var motion := event as InputEventMouseMotion
	if motion and _drag_back.is_empty():
		_update_hover(motion.position)


func _start_soul_drag(local_pos: Vector2) -> void:
	if GameGlobal.dragged_item != null or equipment == null:
		return
	var soul := equipment.soul_at_cell(_cell_at(local_pos))
	if soul == null:
		return

	equipment.remove_soul(soul)
	GameGlobal.begin_drag(soul, local_pos - _soul_rect(soul).position)
	_drag_back = [equipment, soul.cell]
	_hide_tooltip()
	_refresh()


func _finish_soul_drag(mouse_global: Vector2) -> void:
	var soul : Soul = GameGlobal.dragged_item
	GameGlobal.end_drag()

	# 手上已经空了：这一趟早被别人接走了（比如别的行 / 仓库），只管撒手
	if soul == null:
		_drag_back = []
		_refresh()
		return

	# 先问别的落点要不要（仓库、别的部位行，都走 drop_target 分组）
	for target in get_tree().get_nodes_in_group("drop_target"):
		if target.try_drop_at(soul):
			_drag_back = []
			_refresh()
			return

	# 还在自己这一行上：那就是在魂灵区里换个位置
	if equipment and _soul_panel.get_global_rect().has_point(mouse_global):
		if equipment.place_soul(soul, _drop_cell(_to_soul_local(mouse_global), soul)):
			_drag_back = []
			_refresh()
			return

	# 哪儿都放不下就放回原来那格
	if _drag_back.size() == 2:
		var back : Equipment = _drag_back[0]
		if is_instance_valid(back):
			back.place_soul(soul, _drag_back[1])
	_drag_back = []
	_refresh()


# ---------------------------------------------------------------- 视图

# 装着的装备 / 魂灵变了就重挂一遍
func _sync_views() -> void:
	if is_instance_valid(_equipment_view) and _equipment_view.get_parent() == _equipment_slot:
		_equipment_slot.remove_child(_equipment_view)
		_equipment_view.queue_free()
	_equipment_view = null

	for view in _soul_views:
		if is_instance_valid(view) and view.get_parent() == _soul_panel:
			_soul_panel.remove_child(view)
			view.queue_free()
	_soul_views.clear()

	if equipment:
		# 装备按自己的格数画，96×96 的槽里居中（大件 64×96 也放得下，不缩小）
		_equipment_view = ItemView.new(equipment)
		_equipment_view.position = (Vector2(_equipment_slot.size) - Vector2(equipment.cells() * CELL_SIZE)) / 2.0
		_equipment_slot.add_child(_equipment_view)

		for soul in equipment.souls:
			var view := ItemView.new(soul)
			view.place_at_cell()
			_soul_panel.add_child(view)
			_soul_views.append(view)

	# 冷却 / hover / 落点框那层得一直在最上面
	if _overlay:
		_soul_panel.move_child(_overlay, -1)


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_soul_panel.add_child(_overlay)


# 提示框挂在窗口上：挂在行里会被 VBoxContainer 当成新的一行排版。
# 头一次 hover 才建：_ready() 那会儿窗口还在搭自己的子节点，往它身上 add_child() 会被拒
func _build_tooltip() -> void:
	var win := get_window()
	if win == null:
		return
	_tooltip = TOOLTIP_SCENE.instantiate()
	_tooltip.z_index = 10
	win.add_child(_tooltip)


# ---------------------------------------------------------------- 画

# 魂灵区的格线：一格 32 像素，横向 10 格（魂灵都是 2 格高，横着加起来最多占 10 格）
func _draw_soul_lines() -> void:
	var height := _soul_panel.size.y
	for col in Equipment.SOUL_AREA.x + 1:
		var px := float(col * CELL_SIZE) + 0.5
		_soul_panel.draw_line(Vector2(px, 0.0), Vector2(px, height), COLOR_SOUL_LINE)


# 魂灵区上面那层：冷却线、hover 框、落点框
func _draw_overlay() -> void:
	if equipment:
		for soul in equipment.souls:
			_draw_cooldown(_soul_rect(soul), soul)

	# 鼠标指着的那颗
	if _hover_soul:
		_overlay.draw_rect(_soul_rect(_hover_soul), COLOR_HOVER, false, 1.0)

	# 拖着魂灵路过：画落点框（手上那件东西由窗口那层 DragOverlay 画）
	# 判定跟 accept_at 一样宽：落在这一行上就画，框的位置就是它要落的位置
	var dragging := GameGlobal.dragged_item
	if dragging is Soul and equipment and _mouse_over(self):
		var cell := _drop_cell(_to_soul_local(get_global_mouse_position()), dragging)
		var ok : bool = equipment.can_place_soul(dragging as Soul, cell)
		_overlay.draw_rect(_cell_rect(cell, dragging.cells()), COLOR_DROP_OK if ok else COLOR_DROP_BAD, false, 2.0)


# 冷却：从下往上填 + 顶上一条亮线，到顶就重来
func _draw_cooldown(rect: Rect2, soul: Soul) -> void:
	var filled := rect.size.y * soul.cd_progress
	var line_y := rect.end.y - filled
	_overlay.draw_rect(Rect2(Vector2(rect.position.x, line_y), Vector2(rect.size.x, filled)), COLOR_CD_FILL)
	_overlay.draw_line(Vector2(rect.position.x, line_y), Vector2(rect.end.x, line_y), COLOR_CD_LINE, 2.0)


func _refresh() -> void:
	_sync_views()
	_refresh_overlay()


func _refresh_overlay() -> void:
	if _overlay:
		_overlay.queue_redraw()


# ---------------------------------------------------------------- hover 提示

func _update_hover(local_pos: Vector2) -> void:
	_hover_soul = equipment.soul_at_cell(_cell_at(local_pos)) if equipment else null
	if _hover_soul == null:
		_hide_tooltip()
		_refresh_overlay()
		return

	if _tooltip == null:
		_build_tooltip()
	if _tooltip:
		_tooltip.show_for(_hover_soul, _soul_panel.global_position + local_pos, _tooltip_bounds())
	_refresh_overlay()


func _on_soul_exited() -> void:
	_hide_tooltip()
	_refresh_overlay()


func _hide_tooltip() -> void:
	_hover_soul = null
	if _tooltip:
		_tooltip.hide_tip()


# 能占的地方：整个窗口（提示框挂在窗口上，超出窗口的部分会被裁掉）
func _tooltip_bounds() -> Vector2:
	var win := get_window()
	return Vector2(win.size) if win else size


# ---------------------------------------------------------------- 坐标

## 鼠标是不是停在某个控件上（窗口级的判断走 GameGlobal，那里用的是屏幕坐标）
func _mouse_over(canvas: Control) -> bool:
	return GameGlobal.mouse_in_window(get_window()) and canvas.get_global_rect().has_point(get_global_mouse_position())


func _to_soul_local(mouse_global: Vector2) -> Vector2:
	return mouse_global - _soul_panel.global_position


## 指针底下是哪一格
func _cell_at(local_pos: Vector2) -> Vector2i:
	var cell := (local_pos / float(CELL_SIZE)).floor()
	return Vector2i(int(cell.x), int(cell.y))


## 按「抓在哪儿」算落点：东西现在就摆在指针底下那个位置，看到它在哪、松手就落在哪。
## 横竖都顺着**夹进魂灵区**：往右拖过头松手，就落在还放得下的最靠右那一格，不会整个弹回去
## （魂灵都 2 格高、魂灵区也正好 2 格高，所以纵向夹完永远是 0）
func _drop_cell(local_pos: Vector2, item: InventoryItem) -> Vector2i:
	var cell := ((local_pos - GameGlobal.dragged_offset) / float(CELL_SIZE)).floor()
	var cells := item.cells()
	return Vector2i(
		clampi(int(cell.x), 0, maxi(Equipment.SOUL_AREA.x - cells.x, 0)),
		clampi(int(cell.y), 0, maxi(Equipment.SOUL_AREA.y - cells.y, 0))
	)


func _soul_rect(soul: Soul) -> Rect2:
	return _cell_rect(soul.cell, soul.cells()).grow(-1.0)


func _cell_rect(cell: Vector2i, cells: Vector2i) -> Rect2:
	return Rect2(Vector2(cell * CELL_SIZE), Vector2(cells * CELL_SIZE))
