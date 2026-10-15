## 战斗单位：一个普通 Node + 子节点 ASC。
##
## 节点结构（有框架强约束）：
##   BattleUnit
##   └── AbilitySystemComponent   ← 名字必须精确叫这个！
##                                   框架在解析"施法者→ASC"时用的是
##                                   get_node_or_null("AbilitySystemComponent")
##
## 职责：搭属性集 → 建 ASC → 装大脑 → 接死亡/日志信号。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name BattleUnit extends Node

## 本单位的部队全灭时由 BattleManager 判负用
signal died(unit: BattleUnit)

enum Team { PLAYER, ENEMY }

var unit_name: String = ""
var team: Team = Team.PLAYER
var battle: BattleManager
var asc: AbilitySystemComponent
var brain: BattleBrain
var is_dead: bool = false

## 缓存（ASC _ready 会深拷贝属性集，所以要在 add_child 之后再取引用）
var hp_attr: AttributeData
var max_hp_attr: AttributeData


## 建号。调用前请先把本节点 add_child 进场景树。
func setup(p_name: String, p_team: Team, max_hp: float, atk: float, skills: Array[SkillDefinition], p_battle: BattleManager) -> void:
	unit_name = p_name
	team = p_team
	battle = p_battle

	# 1. 属性集（数值先留默认，第 2 步说明为什么）
	var stats := BattleAttributeSet.new()

	# 2. ASC（框架会在 _ready 里对属性集做 duplicate(true) 深拷贝，保证每个单位内存独立。
	#    注意：duplicate 只复制带 STORAGE 标记的属性（即 @export 的），属性集里的普通
	#    var 在入树前被赋的运行时值不会随深拷贝保留。所以初始数值必须在 ASC 入树之后、
	#    通过 ASC 写进那份"活"的属性集里 —— 这也正是框架推荐的属性修改路径。
	asc = AbilitySystemComponent.new()
	asc.name = "AbilitySystemComponent"
	asc.attribute_sets.append(stats)
	add_child(asc)

	asc.get_attribute("max_hp").base_value = max_hp  # 先设 max_hp，hp 的钳制依赖它
	asc.get_attribute("hp").base_value = max_hp
	asc.get_attribute("atk").base_value = atk

	hp_attr = asc.get_attribute("hp")
	max_hp_attr = asc.get_attribute("max_hp")

	# 3. 阵营标签（本案例逻辑以 team 字段为准；标签留给未来的标签过滤器用）
	asc.add_tag(GameplayTags.Team_Player if team == Team.PLAYER else GameplayTags.Team_Enemy)

	# 4. 自动施法大脑
	brain = BattleBrain.new()
	brain.name = "BattleBrain"
	add_child(brain)
	brain.setup(self, skills)

	# 5. 接线：观战日志与死亡
	asc.attribute_changed.connect(_on_attribute_changed)
	asc.active_effect_added.connect(_on_active_effect_added)
	asc.active_effect_removed.connect(_on_active_effect_removed)


## 血量百分比（0~1），TargetRule 的 LOWEST_HP_PERCENT 规则用它排序
func hp_percent() -> float:
	return hp_attr.current_value / maxf(max_hp_attr.current_value, 0.001)


#region 观战日志与死亡
func _log(text: String, color: String = "white") -> void:
	if battle:
		battle.log_line(text, color)


## 统一的掉血/回血日志：所有属性变化（含 DoT 每秒 tick）都会经过这里。
func _on_attribute_changed(attribute_name: String, old_value: float, new_value: float, spec: GameplayEffectSpec) -> void:
	if attribute_name != "hp" or is_dead:
		return

	var source_name := "未知来源"
	if spec and spec.context and spec.context.instigator is BattleUnit:
		source_name = (spec.context.instigator as BattleUnit).unit_name
	var effect_name := "未知效果"
	if spec and spec.effect_def and spec.effect_def.resource_name != "":
		effect_name = spec.effect_def.resource_name

	if new_value < old_value:
		_log("%s 受到【%s】（来自 %s）%.0f 点伤害，HP %.0f → %.0f"
			% [unit_name, effect_name, source_name, old_value - new_value, old_value, new_value], "#ff6e6e")
	elif new_value > old_value:
		_log("%s 回复 %.0f 点生命，HP %.0f → %.0f"
			% [unit_name, new_value - old_value, old_value, new_value], "#7ddf7d")

	_update_wounded_tag(new_value)

	if new_value <= 0.0:
		_die()


## "受伤"状态维护：hp 低于上限就挂 State.Wounded 标签，回满则摘掉。
## 治愈技能就是靠 activation_query 要求这个标签实现"只在受伤时施放"的。
func _update_wounded_tag(hp_value: float) -> void:
	var wounded := hp_value < max_hp_attr.current_value and hp_value > 0.0
	if wounded and not asc.has_tag_exact(GameplayTags.State_Wounded):
		asc.add_tag(GameplayTags.State_Wounded)
	elif not wounded and asc.has_tag_exact(GameplayTags.State_Wounded):
		asc.clear_tag(GameplayTags.State_Wounded)


func _on_active_effect_added(active_effect: ActiveGameplayEffect) -> void:
	var def := active_effect.get_effect_def()
	if is_dead or def == null or def.policy == GameplayEffect.DurationPolicy.INSTANT or _is_internal(def):
		return
	_log("%s 获得状态【%s】（%.1f 秒）" % [unit_name, def.resource_name, active_effect.time_remaining], "#57d9e8")


func _on_active_effect_removed(active_effect: ActiveGameplayEffect) -> void:
	var def := active_effect.get_effect_def()
	if is_dead or def == null or def.policy == GameplayEffect.DurationPolicy.INSTANT or _is_internal(def):
		return
	_log("%s 的状态【%s】结束" % [unit_name, def.resource_name], "gray")


## 冷却等内部效果不播报（靠 State.Charging.* 标签识别）
func _is_internal(def: GameplayEffect) -> bool:
	for tag in def.granted_tags:
		if String(tag).begins_with("State.Charging."):
			return true
	return false


func _die() -> void:
	is_dead = true
	asc.add_tag(GameplayTags.State_Dead)
	brain.set_process(false)
	_log("%s 倒下了！" % unit_name, "#ffcc44")
	died.emit(self)
#endregion
