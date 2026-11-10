class_name NetStatusTickExecution extends PeriodicStatusTickExecution
## 剧毒/再生这类“净值 × 每点数值”的周期结算基类。


## 与对立状态相减后的净值；<= 0 时不结算
func net_stacks(_target_asc: AbilitySystemComponent) -> float:
	return 0.0


## 每点净值的伤害/恢复量
func stack_amount() -> float:
	return 1.0


func execute(_spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var net := net_stacks(target_asc)
	if net <= 0.0:
		return {}
	var amount := net * stack_amount()
	return {"health": amount if is_heal() else -amount}
