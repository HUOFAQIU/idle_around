## 生命再生取灼烧数值的执行计算。
##
## 再生不写死数值，而是在施放时读取 `burn_effect` 里
## `StatusApplyExecution(burn)` 的结算结果。灼烧数值以后被增益或调整时，
## 再生会在下一次释放自动跟随，不需要同时改两份资源。
##
## 暴击按再生自己的 spec 判定；周期部分仍由 `RegenTickExecution` 每秒结算。
class_name RegenFromBurnExecution extends GameplayExecutionCalculation

## 提供灼烧数值的效果；运行时找其中 `attribute_name == "burn"` 的 StatusApplyExecution
@export var burn_effect: GameplayEffect
## 找不到灼烧执行时是否写警告；默认写，避免配置漏了却静默不生效
@export var warn_if_missing: bool = true


func execute(spec: GameplayEffectSpec, _target_asc: AbilitySystemComponent) -> Dictionary:
	var amount := _resolve_burn_amount(spec)
	if amount <= 0.0:
		return {}
	return {"regen": amount}


## 复用 StatusApplyExecution 的结算口径（SetByCaller + 暴击倍率 + 向下取整），
## 保证再生和灼烧读的是同一个数值来源。
func _resolve_burn_amount(spec: GameplayEffectSpec) -> float:
	if burn_effect == null:
		_warn("未配置 burn_effect")
		return 0.0
	for execution in burn_effect.executions:
		if execution is not StatusApplyExecution:
			continue
		var status_execution := execution as StatusApplyExecution
		if status_execution.attribute_name == "burn":
			return status_execution.resolve_amount(spec)
	_warn("burn_effect 里找不到 attribute_name 为 burn 的 StatusApplyExecution")
	return 0.0


func _warn(message: String) -> void:
	if warn_if_missing:
		push_warning("RegenFromBurnExecution：%s" % message)
