## 以魂灵为目标的技能数据资源。
##
## 只放魂灵目标专属字段；共享字段（id、冷却、暴击、吟唱、target_rule 等）在 SkillDefinition。
## target_rule 必须是 SoulTargetRule（domain = SOUL）。

class_name SoulSkillDefinition extends SkillDefinition

## 加速/减速/冻结时长（秒）；0 = 不施加。
@export_range(0.0, 60.0, 0.1) var haste_duration: float = 0.0
@export_range(0.0, 60.0, 0.1) var slow_duration: float = 0.0
@export_range(0.0, 60.0, 0.1) var freeze_duration: float = 0.0

## 充能数值（秒）：直接给目标减少多少当前冷却；0 = 不充能。
@export_range(0.0, 60.0, 0.1) var charge_duration: float = 0.0
