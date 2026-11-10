## 以战斗单位为目标的技能数据资源。
##
## 只放单位目标专属字段；共享字段（id、冷却、暴击、吟唱、target_rule 等）在 SkillDefinition。
## target_rule 必须是 TargetRule（domain = UNIT）。

class_name UnitSkillDefinition extends SkillDefinition

## 施加到每个目标的效果列表（可多个：例如"伤害 + 中毒"）
@export var effects: Array[GameplayEffect] = []

## 命中特效标签：每次结算到目标身上时，在该目标身上播一次（场景要登记到 cue_registry）。
## 留空 = 不播。恐狼用它在两次伤害上交替播放左右爪痕。
@export var hit_cue_tag: StringName = &""

## 投射物场景。留空 = 选完目标立刻结算（比如治疗）；
## 填了 = 每个目标发一支，射向它"此刻"的坐标，飞到谁身上才算打中谁，
## 飞空了就是空了 —— 空箭是设计的一部分，不是 bug。
@export var projectile_scene: PackedScene

## 投射物飞行速度（像素/秒）；0 或负数使用投射物默认速度
@export var projectile_speed: float = 420.0
