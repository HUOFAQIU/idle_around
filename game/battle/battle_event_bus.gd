## 战斗事件总线：模拟层与观察层之间的唯一边界。
##
## 模拟层（BattleManager / BattleUnit / 技能 / 触发器）只发事件，不知道谁在听；
## 遥测、战斗信息窗、控制台、调试工具各自订阅，运行期不再直接依赖它们。
##
## 除通用事件外，另有两个绑定用信号：观察者在收到后才有机会监听 GAS 信号，
## 时机与原先直接调用 CombatTelemetry 时一致（技能授予/触发器登记之前）。
class_name BattleEventBus extends RefCounted

## 通用战斗事件
signal emitted(event: BattleEvent)
## 单位 ASC 已就绪、技能尚未授予：观察者从这里开始监听该单位的 GAS 信号
@warning_ignore("unused_signal")
signal unit_asc_ready(unit: BattleUnit)
## 一颗魂灵的运行期状态与技能已建好：观察者从这里开始监听技能信号
@warning_ignore("unused_signal")
signal soul_runtime_created(unit: BattleUnit, ability: ChargedAbility, runtime: SoulRuntime)


func emit_event(
	category: String,
	type: String,
	fields: Dictionary = {},
	importance: String = BattleEvent.IMPORTANCE_IMPORTANT
) -> void:
	emitted.emit(BattleEvent.new(category, type, fields, importance))
