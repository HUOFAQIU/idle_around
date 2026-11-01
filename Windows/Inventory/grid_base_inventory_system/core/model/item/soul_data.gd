extends ItemData
## 魂灵数据基类，你的魂灵数据类应该继承此类。
##
## 只放静态数据；战斗运行期状态（扫描线/加速/减速/冻结/统计）在
## `game/battle/soul_runtime.gd` 的 SoulRuntime 里，通过 SoulRuntimeDB 查询。
class_name SoulData

## 这颗魂灵在战斗中提供的技能：冷却、范围、效果全写在这份数据里。
## 空着 = 装上去也不提供任何技能
@export var skill: SkillDefinition

## 魂灵触发规则；主动魂灵和被动魂灵都可以配
@export var triggers: Array[PassiveTrigger] = []

## 图鉴文案（本项目扩展）；主动魂灵留空时，图鉴回退到 skill.description
@export_multiline var description: String = ""

## 魂灵标签：用于让特定触发效果只识别特定魂灵（例：Soul.RealEstate）
@export var tags: Array[StringName] = []

## 可装备的部位；ANY = 不限
@export_enum("ANY", "HEADSOUL", "TORSOSOUL", "ARMSSOUL", "LEGSSOUL")
var equip_part: String = "ANY"
