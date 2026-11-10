class_name SkillStep extends Resource
## 技能的一个执行步骤。
##
## 每次释放由 AutoCastAbility 在吟唱结束后按 steps 数组顺序调用。
## 本资源会被同一技能的所有施法者共享；运行时状态只能写在 SkillCastContext，
## 不能写进这里（否则不同单位会互相污染）。


## 执行本步骤；返回是否命中/产生效果。
func execute(_ctx: SkillCastContext) -> SkillStepResult:
	push_error("SkillStep.execute() 未实现：%s" % get_script().resource_path)
	return SkillStepResult.empty("步骤未实现")


## tooltip 单一来源用的展示行；默认不显示。
func tooltip_lines() -> PackedStringArray:
	return PackedStringArray()
