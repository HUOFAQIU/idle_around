class_name SkillStepResult extends RefCounted

var hit: bool = false
var empty_reason: String = ""


static func hit_result() -> SkillStepResult:
	return SkillStepResult.new(true, "")


static func empty(reason: String) -> SkillStepResult:
	return SkillStepResult.new(false, reason)


func _init(p_hit: bool = false, p_empty_reason: String = "") -> void:
	hit = p_hit
	empty_reason = p_empty_reason
