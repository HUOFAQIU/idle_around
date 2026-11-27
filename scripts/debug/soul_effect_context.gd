class_name SoulEffectContext extends GameplayEffectContext

var trace: CombatTrace
var soul_runtime: SoulRuntime


func _init(p_instigator: Node, p_causer: Node = null, p_trace: CombatTrace = null) -> void:
	super(p_instigator, p_causer)
	trace = p_trace
