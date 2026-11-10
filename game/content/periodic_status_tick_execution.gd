class_name PeriodicStatusTickExecution extends GameplayExecutionCalculation
## 周期状态（灼烧/剧毒/生命再生等）的公共基类。
##
## 具体 execution 提供状态元数据与 execute()；BattleUnit 只面向本基类分发，
## CombatNames 只读 status_display_name()，不再按具体类型 if/elif。

enum PopupStyle {
	DAMAGE,
	BURN,
	POISON,
	REGEN,
}


## 状态对应的属性名（burn / poison / regen ...）
func status_attribute() -> String:
	push_error("PeriodicStatusTickExecution.status_attribute() 未实现：%s" % get_script().resource_path)
	return ""


## 日志/调试显示名
func status_display_name() -> String:
	return StatusText.display_name(status_attribute())


## 属性归零后是否移除周期效果
func remove_when_zero() -> bool:
	return false


## 日志颜色
func log_color() -> String:
	return StatusText.log_color(status_attribute())


## 飘字样式
func popup_style() -> PopupStyle:
	return PopupStyle.DAMAGE


## 是否恢复生命（决定日志格式）
func is_heal() -> bool:
	return false


## 子类实现
func execute(_spec: GameplayEffectSpec, _target_asc: AbilitySystemComponent) -> Dictionary:
	return {}


## 从效果资源里找周期状态 execution；没有返回 null
static func find(effect: GameplayEffect) -> PeriodicStatusTickExecution:
	if effect == null:
		return null
	for execution in effect.executions:
		if execution is PeriodicStatusTickExecution:
			return execution as PeriodicStatusTickExecution
	return null
