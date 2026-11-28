extends Resource
class_name MapData

## 运行期稳定 ID，存档和 MapCatalog 用
@export var content_id: StringName = &""
## 地图显示名（tooltip 标题和按钮文字）
@export var display_name: String = ""
## 地图物品卡面图标
@export var icon: Texture2D
## 地图等级区间 [min, max]，约束本图内所有刷怪池的等级范围
@export var level_range: Vector2i = Vector2i(1, 5)
## 地图稀有度 1~5；决定掉落魂灵的有效情绪总量区间
@export_range(1, 5) var rarity: int = 1
## 地图默认天气预设（留空时由战斗视图使用默认晴天）
@export var weather_preset: WeatherPreset

@export_group("阶位刷怪池")
## 小怪池：按权重随机刷出
@export var mob_pool: Array[MapSpawnPoolEntry] = []
## 本图小怪总数
@export var mob_total: int = 0
## 小怪刷新间隔（秒）
@export_range(0.05, 60.0, 0.05) var mob_interval_seconds: float = 1.0
## 精英池：击杀任意小怪累计满阈值时按权重随机刷出
@export var elite_pool: Array[MapSpawnPoolEntry] = []
## 每击杀多少只任意小怪刷 1 只精英（0 = 不刷精英）
@export var elite_every_mob_kills: int = 10
## 首领条目：击杀全部小怪后刷出，击败首领通关
@export var boss_entry: MapSpawnPoolEntry


func collect_problems() -> Array[String]:
	var problems: Array[String] = []
	if content_id.is_empty():
		problems.append("地图缺少 content_id")
	if display_name.is_empty():
		problems.append("%s：缺少 display_name" % content_id)
	if rarity < 1 or rarity > 5:
		problems.append("%s：稀有度必须在 1~5" % content_id)
	if level_range.x < 1 or level_range.y < level_range.x:
		problems.append("%s：level_range 非法 %s" % [content_id, level_range])
	if mob_total <= 0:
		problems.append("%s：mob_total 必须大于 0" % content_id)
	if mob_pool.is_empty():
		problems.append("%s：小怪池不能为空" % content_id)
	if mob_interval_seconds <= 0.0:
		problems.append("%s：mob_interval_seconds 必须大于 0" % content_id)
	if elite_every_mob_kills < 0:
		problems.append("%s：elite_every_mob_kills 不能为负" % content_id)
	for entry in mob_pool:
		if entry == null:
			problems.append("%s：小怪池存在空项" % content_id)
			continue
		entry.collect_problems(problems, level_range, "%s 小怪池" % content_id)
	for entry in elite_pool:
		if entry == null:
			problems.append("%s：精英池存在空项" % content_id)
			continue
		entry.collect_problems(problems, level_range, "%s 精英池" % content_id)
	if boss_entry != null:
		boss_entry.collect_problems(problems, level_range, "%s 首领" % content_id)
	return problems
