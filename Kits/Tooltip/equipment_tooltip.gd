class_name EquipmentTooltip
extends TooltipBase

## 装备的提示框：名字 + 它的魂灵区，10 格宽 2 格高、跟装备面板一样 1:1。
## 魂灵的提示框是另一个（`Kits/Tooltip/soul_tooltip.gd`）。

## 魂灵区缩略图一格画多少像素（跟装备面板一格一样大）
const SOUL_CELL : int = InventoryItem.CELL_SIZE

@onready var _soul_panel : Panel = $BG/VBoxContainer/SoulPanel


## 显示这件装备的提示。anchor 是鼠标位置、bounds 是能占的地方（都是所在容器的坐标）
func show_for(equipment: Equipment, anchor: Vector2, bounds: Vector2) -> void:
	_clear_views()
	_name_label.text = equipment.name

	# 整片魂灵区照原样摆出来
	_soul_panel.custom_minimum_size = Vector2(Equipment.SOUL_AREA * SOUL_CELL)
	for soul in equipment.souls:
		var view := ItemView.new(soul)
		view.position = Vector2(soul.cell * SOUL_CELL)
		_soul_panel.add_child(view)

	visible = true
	place_near(anchor, bounds)


# 先摘下来再排队删：留着下一帧画会跟新内容叠在一起
func _clear_views() -> void:
	for child in _soul_panel.get_children():
		if child is ItemView:
			_soul_panel.remove_child(child)
			child.queue_free()
