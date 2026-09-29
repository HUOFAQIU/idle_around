class_name ItemView
extends Control

## 一件东西长什么样，就这一处说了算：按大小挑 `Tokens/` 下的场景，场景自己带美术。
## 仓库、装备面板、拖拽时跟着鼠标的那件、提示框里画的都是同一个视图。
## （以前这里是 `Scripts/item_draw.gd`，代码画一个色块加名字；色块那套已经换掉了）

const EQUIPMENT_SCENES : Dictionary = {
	InventoryItem.Size.SMALL: preload("res://Tokens/Equipments/equipment_12.tscn"),
	InventoryItem.Size.MEDIUM: preload("res://Tokens/Equipments/equipment_22.tscn"),
	InventoryItem.Size.LARGE: preload("res://Tokens/Equipments/equipment_23.tscn"),
}

const SOUL_SCENES : Dictionary = {
	InventoryItem.Size.SMALL: preload("res://Tokens/Souls/soul_12.tscn"),
	InventoryItem.Size.MEDIUM: preload("res://Tokens/Souls/soul_22.tscn"),
	InventoryItem.Size.LARGE: preload("res://Tokens/Souls/soul_33.tscn"),
}

## 画的是哪件东西
var item : InventoryItem


func _init(p_item: InventoryItem) -> void:
	item = p_item
	size = Vector2(p_item.cells() * InventoryItem.CELL_SIZE)
	# 视图只管显示，鼠标事件一律放过去，不然底下的拖拽 / hover 就收不到了
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var scene := scene_for(p_item)
	if scene:
		var art := scene.instantiate() as Control
		add_child(art)
		_check_size(art)
	# 得等挂上去之后再递归：场景自己 `_ready()` 里加的子节点也要按一遍
	_ignore_mouse_recursive(self)


## 这件东西该用哪个场景
static func scene_for(p_item: InventoryItem) -> PackedScene:
	var table := EQUIPMENT_SCENES if p_item is Equipment else SOUL_SCENES
	return table.get(p_item.size)


## 按自己的格子上位（容器同步时用；拖拽那种「跟着鼠标跑」的场景由调用方直接设 position）
func place_at_cell() -> void:
	position = Vector2(item.cell * InventoryItem.CELL_SIZE)


## 场景大小得跟占的格子对得上，不然美术和它实际占的地方会错位
func _check_size(art: Control) -> void:
	var want := Vector2(item.cells() * InventoryItem.CELL_SIZE)
	if art.size != want:
		push_warning("ItemView：%s 的美术是 %s，跟它占的 %s 对不上" % [art.name, art.size, want])


## 场景里除了根节点，ColorRect / NinePatchRect / Panel 这些默认都会吃鼠标事件，
## 不递归按一遍的话拖拽和 hover 会莫名其妙失灵
func _ignore_mouse_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse_recursive(child)
