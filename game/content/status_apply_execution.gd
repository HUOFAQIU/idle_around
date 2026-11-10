## 通用异常状态施加。
##
## 施加数值优先取主动技能步骤的 `Data.SkillMagnitude`，其次触发器的
## `Data.TriggerMagnitude`，最后用 base_amount，再乘释放时已经判定好的暴击倍率。
## 最终数值向下取整，和灼烧/剧毒的整数口径保持一致。
class_name StatusApplyExecution extends GameplayExecutionCalculation

## 要写入的状态属性名：burn / poison / regen
@export var attribute_name: String = "burn"
## 主动技能没有 SetByCaller 时使用的基础数值
@export var base_amount: float = 0.0


func execute(spec: GameplayEffectSpec, _target_asc: AbilitySystemComponent) -> Dictionary:
	if attribute_name.is_empty():
		return {}

	var amount := resolve_amount(spec)
	if amount <= 0.0:
		return {}
	return {attribute_name: amount}


## 本次施加的最终数值：SetByCaller 优先，再乘释放时判定好的暴击倍率，向下取整。
## 供派生效果读取同一份结算口径（例如再生读取灼烧值）。
func resolve_amount(spec: GameplayEffectSpec) -> float:
	var amount := base_amount
	var multiplier := 1.0
	if spec != null:
		var skill_amount := spec.get_set_by_caller_magnitude(GameplayTags.Data_SkillMagnitude, -1.0)
		var trigger_amount := spec.get_set_by_caller_magnitude(GameplayTags.Data_TriggerMagnitude, -1.0)
		if skill_amount >= 0.0:
			amount = skill_amount
		elif trigger_amount >= 0.0:
			amount = trigger_amount
		multiplier = CritResolution.multiplier(spec)

	return floor(amount * multiplier)


## 状态的显示名；未知属性回退到属性名。
func status_display_name() -> String:
	return StatusText.display_name(attribute_name)
