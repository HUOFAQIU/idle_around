## 目标规则公共基类。
##
## 具体规则由两个子类实现：
##   TargetRule      选战斗单位，返回批次 Array[Array[BattleUnit]]
##   SoulTargetRule  选魂灵能力，返回 Array[ChargedAbility]
##
## SkillDefinition 只暴露一个 target_rule 字段，具体走哪条分支由
## AutoCastAbility 按实际类型判断。

class_name TargetRuleBase extends Resource
