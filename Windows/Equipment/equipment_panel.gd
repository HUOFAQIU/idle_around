class_name EquipmentPanel
extends VBoxContainer

## 装备面板：六行 SlotCell + 面板级的活儿（哪个部位装了哪件、往哪一行丢）。
## 每一行自己的画、hover 提示、拖拽都归 SlotCell 管，这里不碰坐标。

## 面板上的六个部位，从上到下（跟场景里 SlotCell 的先后顺序一一对应）
const PART_ORDER : Array = [
	Equipment.Part.WEAPON, Equipment.Part.HEAD, Equipment.Part.BODY,
	Equipment.Part.FOOT, Equipment.Part.NECK, Equipment.Part.RING,
]

## 某个部位空出来了（被顶下来 / 右键卸下来），窗口负责把那件连同它的魂灵丢进仓库临时页
signal equipment_removed(equipment: Equipment)

var _rows : Array[SlotCell] = []


func _ready() -> void:
	for child in get_children():
		if child is SlotCell:
			_rows.append(child)
	for i in _rows.size():
		if i >= PART_ORDER.size():
			break
		_rows[i].setup(PART_ORDER[i])
		_rows[i].equipment_removed.connect(_on_row_removed)

	add_to_group("drop_target")
	# 仓库换装时要找到我
	add_to_group("equipment_panel")


func _row_for(part: Equipment.Part) -> SlotCell:
	for row in _rows:
		if row.part == part:
			return row
	return null


## 装上一件；原来那件被换下来会走 equipment_removed
func equip(equipment: Equipment) -> Equipment:
	var row := _row_for(equipment.part)
	if row == null:
		return null
	return row.equip(equipment)


## 别人（仓库）松手时会问：这一下能放在你这儿吗
func try_drop_at(item: InventoryItem) -> bool:
	if not is_visible_in_tree():
		return false
	# 先确认鼠标真在这个窗口里，不然拿到的是上次离开时的旧位置
	if not GameGlobal.mouse_in_window(get_window()):
		return false

	var mouse := get_global_mouse_position()
	for row in _rows:
		if row.accept_at(mouse, item):
			return true
	return false


func _on_row_removed(equipment: Equipment) -> void:
	equipment_removed.emit(equipment)
