class_name Soul
extends InventoryItem

## 技能释放间隔（秒）：扫描线从下走到顶要这么久
var interval : float = 2.0
## 技能描述，hover 的时候显示
var description : String = ""
## 冷却进度：0 = 刚放完，1 = 要放了。装备面板每帧往前推
var cd_progress : float = 0.0


## 魂灵跟装备一样分大中小：大 3×2 / 中 2×2 / 小 1×2
func _init(p_cell: Vector2i, p_color: Color, p_name: String = "", p_size: Size = Size.MEDIUM) -> void:
	super(p_size, p_cell, p_color)
	name = p_name
 
