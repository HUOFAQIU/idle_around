class_name InventoryItem
extends RefCounted

## 一格多少像素。仓库和装备面板都按这个画，改一处两边一起变
const CELL_SIZE : int = 32

## 装备尺寸，数值是占用的格数：宽 × 高
enum Size {
	SMALL,   ## 小型 1×2
	MEDIUM,  ## 中型 2×2
	LARGE,   ## 大型 3×2
}

const SIZE_CELLS : Dictionary = {
	Size.SMALL: Vector2i(1, 2),
	Size.MEDIUM: Vector2i(2, 2),
	Size.LARGE: Vector2i(3, 2),
}

var size : Size
## 左上角所在的格
var cell : Vector2i
## 色块底色
var color : Color

## 装备名，写在色块上（塞不下就不写），也显示在详情面板里
var name : String = ""
## 物理伤害范围：最小、最大；0-0 表示这东西不打人（护甲之类）
var damage : Vector2i = Vector2i.ZERO


func _init(p_size: Size, p_cell: Vector2i, p_color: Color) -> void:
	size = p_size
	cell = p_cell
	color = p_color


## 占几格：宽 × 高
func cells() -> Vector2i:
	return SIZE_CELLS[size]


## 占用区域，单位是格
func cell_rect() -> Rect2i:
	return Rect2i(cell, cells())
