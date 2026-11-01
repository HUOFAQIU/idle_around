## 带调试 trace 的 GameplayEffectContext。
##
## 所有项目侧创建的 spec 都用它；GAS 内部自己创建的 context（例如
## apply_gameplay_effect 的便捷路径）没有 trace，调试窗口按“无 trace”处理。
## 不修改 addons/GodotGAS。
class_name SoulEffectContext extends GameplayEffectContext

var trace: CombatTrace


func _init(p_instigator: Node, p_causer: Node = null, p_trace: CombatTrace = null) -> void:
	super(p_instigator, p_causer)
	trace = p_trace
