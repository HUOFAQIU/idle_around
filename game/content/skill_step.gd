class_name SkillStep extends Resource


func execute(_ctx: SkillCastContext) -> SkillStepResult:
	push_error("SkillStep.execute() 未实现：%s" % get_script().resource_path)
	return SkillStepResult.empty("步骤未实现")


func tooltip_lines() -> PackedStringArray:
	return PackedStringArray()
