extends ItemData
## 魂灵数据基类，你的魂灵数据类应该继承此类。
##
## 只放静态数据；战斗运行期状态（扫描线/加速/减速/冻结/统计）在
## `game/battle/soul_runtime.gd` 的 SoulRuntime 里，通过 SoulRuntimeDB 查询。
class_name SoulData

## 尺寸标签；每颗魂灵必须且只能带一个，决定 tooltip 的 [ 小型 / 中型 / 大型 ]
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

## tooltip 正文段落；格式化器用分隔线连接，{cooldown} 会替换成技能冷却。
## 留空 = 不提供正文，tooltip 显示「无」。
@export var tooltip_blocks: Array[String] = []

## 魂灵类型：语义分类（例：Soul.types.Wolf），供触发规则筛选；显示名见 SoulText
@export var types: Array[StringName] = []

## 魂灵标签：见闻窗口筛选用（例：Soul.tags.Small、Soul.tags.Burn）
@export var tags: Array[StringName] = []


## 取尺寸标签；没配时返回空（ModLoader 会报错）
func size_tag() -> StringName:
	for tag in SIZE_TAGS:
		if tags.has(tag):
			return tag
	return &""
