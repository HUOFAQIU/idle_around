extends ItemData
## 魂灵数据基类，你的魂灵数据类应该继承此类
class_name SoulData

## 这颗魂灵在战斗中提供的技能：冷却、范围、效果全写在这份数据里。
## 空着 = 装上去也不提供任何技能
@export var skill: SkillDefinition
