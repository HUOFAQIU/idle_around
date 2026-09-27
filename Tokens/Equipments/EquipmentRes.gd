class_name EquipmentRes
extends Resource

enum Part {
	WEAPON,  ## 武器
	HEAD,    ## 头部
	BODY,    ## 身体
	FOOT,    ## 鞋子
	NECK,    ## 项链
	RING,    ## 戒指
}

enum Size {
	ONEONE,   ## 小型 1×1
	ONETWO,  ## 小型 1×2
	TWOONE,   ## 小型 2×1
	TWOTWO,   ## 中型 2×2
	TWOTHREE,   ## 大型 2×3
	THREETWO,   ## 大型 3×2
	THREETHREE,   ## 大型 3×3
}

const SIZE_CELLS : Dictionary = {
	Size.ONETWO: Vector2i(1, 2),
	Size.TWOTHREE: Vector2i(2, 3),
}

@export var name : String
## 暂不用
@export var eid : String
@export var equipment_part : Part
@export var equipment_size : Size
#@export var my_soul : Soul
