class_name PeriodicStatusTickExecution extends GameplayExecutionCalculation

enum PopupStyle {
	DAMAGE,
	BURN,
	POISON,
	REGEN,
}


func status_attribute() -> String:
	push_error("PeriodicStatusTickExecution.status_attribute() 未实现：%s" % get_script().resource_path)
	return ""


func status_display_name() -> String:
	return StatusText.display_name(status_attribute())


func remove_when_zero() -> bool:
	return false


func log_color() -> String:
	return StatusText.log_color(status_attribute())


func popup_style() -> PopupStyle:
	return PopupStyle.DAMAGE


func is_heal() -> bool:
	return false


func execute(_spec: GameplayEffectSpec, _target_asc: AbilitySystemComponent) -> Dictionary:
	return {}


static func find(effect: GameplayEffect) -> PeriodicStatusTickExecution:
	if effect == null:
		return null
	for execution in effect.executions:
		if execution is PeriodicStatusTickExecution:
			return execution as PeriodicStatusTickExecution
	return null
