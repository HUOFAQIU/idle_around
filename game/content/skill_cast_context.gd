class_name SkillCastContext extends RefCounted
## 一次技能释放的上下文；steps 之间共享。

var ability: AutoCastAbility
var battle: BattleManager
var trace: CombatTrace
var caster_unit: BattleUnit
var caster_asc: AbilitySystemComponent
var release_index: int = 0
var release_count: int = 1
## 步骤间共享数据；键由步骤自行约定。
## 用于“前一步选中的目标留给后一步用”这类组合，替代把运行时状态写进共享资源。
var blackboard: Dictionary = {}


func _init(
	p_ability: AutoCastAbility,
	p_battle: BattleManager,
	p_trace: CombatTrace,
	p_release_index: int,
	p_release_count: int
) -> void:
	ability = p_ability
	battle = p_battle
	trace = p_trace
	caster_unit = p_ability.caster_unit()
	caster_asc = p_ability.owner_asc
	release_index = p_release_index
	release_count = p_release_count
