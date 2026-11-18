extends ItemData
## 背包和地图板上的地图实例。
##
## 静态数据在 MapData；这里只挂地图资源并负责物品表现。
## 卡面文字显示「地图：森林」，tooltip 标题显示「森林」，两者分开。
class_name MapItemData

## 这张地图对应的配置
@export var map_data: MapData


## 地图 id；没有配置时返回空
func map_id() -> StringName:
	return map_data.content_id if map_data != null else &""


## tooltip 标题用地图名，卡面 ItemView 仍用 item_name
func tooltip_title() -> String:
	return map_data.display_name if map_data != null else item_name
