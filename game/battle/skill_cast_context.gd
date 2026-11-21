class_name SkillCastContext extends RefCounted

var ability: AutoCastAbility
var battle: BattleManager
var trace: CombatTrace
var caster_unit: BattleUnit
var caster_asc: AbilitySystemComponent
var release_index: int = 0
var release_count: int = 1
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
