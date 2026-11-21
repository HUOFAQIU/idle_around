extends ItemData
class_name MapItemData

## 这张地图对应的配置
@export var map_data: MapData


func map_id() -> StringName:
	return map_data.content_id if map_data != null else &""


func tooltip_title() -> String:
	return map_data.display_name if map_data != null else item_name
