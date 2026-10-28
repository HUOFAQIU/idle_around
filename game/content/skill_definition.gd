## 技能数据资源：一个技能 = 一份数据。
##
## 把"技能描述"翻译成这些字段；新增技能 = 新增一份数据，不改任何代码。
## 生产项目里把这些字段做成 .tres 资源给策划配，本案例为了单文件可读改为代码构造。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name SkillDefinition extends Resource

## 英文短 id（用于 ability_tag 等内部标识）
@export var id: String = ""

## 面向玩家的技能描述（与下面字段一一对应）
@export_multiline var description: String = ""

## 施加到每个目标的效果列表（可多个：例如"伤害 + 中毒"）
@export var effects: Array[GameplayEffect] = []

## 冷却时长（秒）：只读取 duration，不再把效果挂到 ASC。
## 充能由 ChargedAbility 按帧累加，充满后释放。
@export var cooldown_effect: GameplayEffect

## 暴击率（0~1）与暴击倍率；伤害和治疗共用
@export_range(0.0, 1.0, 0.01) var crit_chance: float = 0.0
@export var crit_multiplier: float = 1.5

## 目标选择规则：
##   TargetRule      选战斗单位，使用 effects / projectile_scene
##   SoulTargetRule  选魂灵，使用 haste_duration
@export var target_rule: TargetRuleBase

## 加速/减速时长（秒）；0 = 不施加。只有 target_rule 是 SoulTargetRule 时才生效。
@export_range(0.0, 60.0, 0.1) var haste_duration: float = 0.0
@export_range(0.0, 60.0, 0.1) var slow_duration: float = 0.0

## 充能数值（秒）：直接给目标减少多少当前冷却；0 = 不充能。
@export_range(0.0, 60.0, 0.1) var charge_duration: float = 0.0

## 投射物场景。留空 = 选完目标立刻结算（比如治疗）；
## 填了 = 每个目标发一支，射向它"此刻"的坐标，飞到谁身上才算打中谁，
## 飞空了就是空了 —— 空箭是设计的一部分，不是 bug。
@export var projectile_scene: PackedScene

## 投射物飞行速度（像素/秒）；0 或负数使用投射物默认速度
@export var projectile_speed: float = 420.0

## 吟唱时间（秒）；0 = 瞬发。吟唱结束会重新选目标，避免对着尸体放大。
@export_range(0.0, 10.0, 0.1) var cast_time: float = 0.0

## 施法条件：身上必须有其中任意一个标签才能放（例如"只在受伤时治疗"）。
## 内部会被翻译成 GameplayAbility.activation_query，由框架的门卫统一检查。
@export var cast_requires_tags: Array[StringName] = []
