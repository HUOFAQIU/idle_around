class_name Equipment
extends InventoryItem

## 装备部位，目前就这六个
enum Part {
	WEAPON,  ## 武器
	HEAD,    ## 头部
	BODY,    ## 身体
	FOOT,    ## 鞋子
	NECK,    ## 项链
	RING,    ## 戒指
}

const PART_NAMES : Dictionary = {
	Part.WEAPON: "武器",
	Part.HEAD: "头部",
	Part.BODY: "身体",
	Part.FOOT: "鞋子",
	Part.NECK: "项链",
	Part.RING: "戒指",
}

## 魂灵区：横向 10 格、高 2 格。魂灵都是 2 格高，所以就是横向加起来最多占 10 格
const SOUL_AREA : Vector2i = Vector2i(10, 2)

## 这件是哪个部位的
var part : Part = Part.WEAPON
## 装在上面的魂灵；每颗魂灵的 cell 是它在魂灵区里的左上角格子（跟仓库里放东西一个规矩）
var souls : Array[Soul] = []


func _init(p_part: Part, p_size: Size, p_cell: Vector2i, p_color: Color) -> void:
	super(p_size, p_cell, p_color)
	part = p_part


## 盖住这一格的魂灵，没有就返回 null
func soul_at_cell(cell: Vector2i) -> Soul:
	for soul in souls:
		if soul.cell_rect().has_point(cell):
			return soul
	return null


## 这块地方放得下吗：在魂灵区里，而且不和已经装着的魂灵重叠
func can_place_soul(soul: Soul, cell: Vector2i) -> bool:
	var rect := Rect2i(cell, soul.cells())
	if rect.position.x < 0 or rect.position.y < 0:
		return false
	if rect.end.x > SOUL_AREA.x or rect.end.y > SOUL_AREA.y:
		return false
	for other in souls:
		if other.cell_rect().intersects(rect):
			return false
	return true


## 装上魂灵；放不下就返回 false（魂灵自己的坐标会跟着变）
func place_soul(soul: Soul, cell: Vector2i) -> bool:
	if not can_place_soul(soul, cell):
		return false
	soul.cell = cell
	souls.append(soul)
	return true


## 把魂灵从这件装备上摘下来
func remove_soul(soul: Soul) -> void:
	if souls.has(soul):
		souls.erase(soul)
