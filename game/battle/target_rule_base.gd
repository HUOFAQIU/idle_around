class_name TargetRuleBase extends Resource

enum Domain { UNIT, SOUL }


func domain() -> Domain:
	push_error("TargetRuleBase.domain() 未实现：%s" % get_script().resource_path)
	return Domain.UNIT


func max_range_cells() -> int:
	return 0
