extends Resource
class_name MapData

## 运行期稳定 ID，存档和 MapCatalog 用
@export var content_id: StringName = &""
## 地图显示名（tooltip 标题和按钮文字）
@export var display_name: String = ""
## 地图物品卡面图标
@export var icon: Texture2D
## 刷怪配置
@export var spawn_entries: Array[MapSpawnEntry] = []


func collect_problems() -> Array[String]:
	var problems: Array[String] = []
	if content_id.is_empty():
		problems.append("地图缺少 content_id")
	if display_name.is_empty():
		problems.append("%s：缺少 display_name" % content_id)
	if spawn_entries.is_empty():
		problems.append("%s：没有任何刷怪条目" % content_id)
	var has_time_entry := false
	for entry in spawn_entries:
		if entry == null:
			problems.append("%s：刷怪条目为空" % content_id)
			continue
		if entry.condition == MapSpawnEntry.Condition.TIME_INTERVAL:
			has_time_entry = true
		entry.collect_problems(problems)
	if not has_time_entry:
		problems.append("%s：至少需要一个时间刷怪条目" % content_id)
	return problems
