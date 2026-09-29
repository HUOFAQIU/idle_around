class_name InventoryItem
extends RefCounted

## 一格多少像素。仓库和装备面板都按这个画，改一处两边一起变
const CELL_SIZE : int = 32

## 大中小。装备和魂灵各是各的尺寸，具体占几格由子类的 SIZE_CELLS 说了算
enum Size {
	SMALL,   ## 小型
	MEDIUM,  ## 中型
	LARGE,   ## 大型
}

var size : Size
## 左上角所在的格
var cell : Vector2i

## 名字，hover 的时候写在提示框上（格子上不写）
var name : String = ""


func _init(p_size: Size, p_cell: Vector2i) -> void:
	size = p_size
	cell = p_cell


## 占几格：宽 × 高。装备和魂灵的大中小不是同一套尺寸，子类必须覆盖
func cells() -> Vector2i:
	push_error("InventoryItem.cells() 必须由子类覆盖")
	return Vector2i.ONE


## 占用区域，单位是格
func cell_rect() -> Rect2i:
	return Rect2i(cell, cells())
