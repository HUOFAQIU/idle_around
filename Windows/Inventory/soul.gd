class_name Soul
extends InventoryItem

## 魂灵占几格。跟装备不是一套：魂灵都 2 格高，宽的分三档
const SIZE_CELLS : Dictionary = {
	Size.SMALL: Vector2i(1, 2),
	Size.MEDIUM: Vector2i(2, 2),
	Size.LARGE: Vector2i(3, 2),
}

## 冷却进度：0 = 刚放完，1 = 要放了。装备面板每帧往前推。
## 推多快归装备面板管（`SlotCell.cooldown_seconds`），魂灵自己不带时长
var cd_progress : float = 0.0


func _init(p_cell: Vector2i, p_name: String = "", p_size: Size = Size.MEDIUM) -> void:
	super(p_size, p_cell)
	name = p_name


func cells() -> Vector2i:
	return SIZE_CELLS[size]
