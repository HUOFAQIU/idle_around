extends ItemData
class_name SoulData

const SIZE_TAGS : Array[StringName] = [
	&"Soul.tags.Small",
	&"Soul.tags.Medium",
	&"Soul.tags.Large",
]

## 这颗魂灵在战斗中提供的技能：冷却、范围、效果全写在这份数据里。
## 空着 = 装上去也不提供任何技能
@export var skill: SkillDefinition

## 魂灵触发规则；主动魂灵和被动魂灵都可以配
@export var triggers: Array[PassiveTrigger] = []

## tooltip 正文段落；格式化器用分隔线连接，{cooldown}/{cast_times}/{damage}/{damage_per_soul} 会替换。
## 留空 = 不提供正文，tooltip 显示「无」。
@export var tooltip_blocks: Array[String] = []

## 魂灵类型：语义分类（例：Soul.types.Wolf），供触发规则筛选；显示名见 SoulText
@export var types: Array[StringName] = []

## 魂灵标签：见闻窗口筛选用（例：Soul.tags.Small、Soul.tags.Burn）
@export var tags: Array[StringName] = []

## 情绪参数范围：情绪 ID → Vector2(最低端值, 最高端值)；占比 0 取左端，100 取右端。
## 冷却写在冷却情绪键下，其余键为有效情绪；空 = 这颗魂灵不参与情绪系统。
@export var emotion_ranges: Dictionary = {}

## 实例情绪构成：情绪 ID → 整数百分比，合计 100；模板为空，由掉落时 roll 写入。
@export var emotions: Dictionary = {}


func make_instance() -> ItemData:
	var instance := super.make_instance() as SoulData
	instance.emotions = emotions.duplicate()
	return instance


func size_tag() -> StringName:
	for tag in SIZE_TAGS:
		if tags.has(tag):
			return tag
	return &""
