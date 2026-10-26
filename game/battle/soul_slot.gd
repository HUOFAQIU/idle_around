## 战斗中一颗已装备魂灵的位置信息。
##
## 用于“左/右相邻”判断和“同冷却从左到右”的触发顺序：
##   container_name  所在部位容器（cell_0..cell_3）
##   column          魂灵占用的最左列
##   width           魂灵占用的列数

class_name SoulSlot extends RefCounted

var soul: SoulData
var container_name: String = ""
var column: int = 0
var width: int = 1
