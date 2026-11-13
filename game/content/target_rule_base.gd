## 目标规则公共基类。
##
## 具体规则由两个子类实现：
##   TargetRule      选战斗单位，返回批次 Array[Array[BattleUnit]]
##   SoulTargetRule  选魂灵能力，返回 Array[ChargedAbility]
##
## target_rule 挂在 SkillStep 的具体子类上（UnitSkillStep / SoulSkillStep），由各步骤自己调用 resolve()。

class_name TargetRuleBase extends Resource

## 目标域：决定技能按战斗单位还是魂灵结算。
enum Domain { UNIT, SOUL }


## 子类必须实现；未实现时报错并返回 UNIT，避免静默走错分支。
func domain() -> Domain:
	push_error("TargetRuleBase.domain() 未实现：%s" % get_script().resource_path)
	return Domain.UNIT


## 工具展示用的最大攻击距离（格）；魂灵目标规则返回 0。
func max_range_cells() -> int:
	return 0
