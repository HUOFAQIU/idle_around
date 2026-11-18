extends ItemData
## 数量石：只做物品和 tooltip，使用效果暂未实现。
##
## 1×1、文字显示「数量石」；不能放进地图板，也不会被消耗。
class_name QuantityStoneData

## tooltip 正文段落；与魂灵一样按段落渲染
@export var tooltip_blocks: Array[String] = []
