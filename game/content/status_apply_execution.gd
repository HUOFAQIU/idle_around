## 通用异常状态施加。
##
## 施加数值优先取触发器的 SetByCaller `Data.TriggerMagnitude`；
## 没有时用 base_amount（主动技能使用），再乘释放时已经判定好的暴击倍率。
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
		var trigger_amount := spec.get_set_by_caller_magnitude(PassiveTrigger.MAGNITUDE_TAG, -1.0)
		if trigger_amount >= 0.0:
			amount = trigger_amount
		multiplier = maxf(
			spec.get_set_by_caller_magnitude(SoulDamageExecution.CRIT_MULTIPLIER_TAG, 1.0),
			0.0
		)

	return floor(amount * multiplier)
