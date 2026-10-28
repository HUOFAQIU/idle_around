## 战斗单位：战场上的一个 token，逻辑和表现都在它身上。
##
## 节点结构（有框架强约束）：
##   BattleUnit (Node2D)          ← 位置跟着 cell 走
##   ├── AbilitySystemComponent   ← 名字必须精确叫这个！
##                                   框架在解析"施法者→ASC"时用的是
##                                   get_node_or_null("AbilitySystemComponent")
##                                   属性集配在它的 attribute_sets 上
##   ├── BattleBrain              ← 自动施法
##   ├── HealthBar (UnitHealthBar)← 血条（可选，有就绑上）
##   ├── Body (Sprite2D)          ← 本体贴图（可选，纯显示）
##   └── Name (Label)             ← 头顶名字（可选，有就自动填 unit_name）
##
## 位置：cell 是逻辑坐标（选目标、寻路都算它），position 是像素投影，
## 由 BattleManager.cell_to_world() 换算 —— 战斗逻辑不依赖地图节点。

class_name BattleUnit extends Node2D

## 单位倒下时发出
signal died(unit: BattleUnit)

enum Team { PLAYER, ENEMY }

@export var unit_name: String = ""
@export var team: Team = Team.PLAYER
## 血量上限（在场景根节点上配置）
@export var max_health: float = 100.0
## 死亡掉落（怪物场景里配置；玩家留空）
@export var drops: Array[DropEntry] = []
## 场景配置的魂灵（怪物用；玩家场景留空，运行时从装备读取）
@export var souls: Array[SoulData] = []

var battle: BattleManager
var asc: AbilitySystemComponent
var brain: BattleBrain
var is_dead: bool = false
var _death_queued: bool = false

## 战场格子坐标（逻辑位置）
var cell: Vector2i = Vector2i.ZERO

## 缓存（ASC _ready 会深拷贝属性集，所以要在 add_child 之后再取引用）
var health_attr: AttributeData
var max_health_attr: AttributeData


## 从场景建号：ASC、外观、能力都由场景预先配置。
## 场景根节点已经入树（子节点的 _ready 跑过）之后调用。
## passive_effects 只给玩家用：开战前挂上被动魂灵的属性效果。
func setup_from_scene(p_battle: BattleManager, passive_effects: Array[GameplayEffect] = []) -> void:
	battle = p_battle

	asc = get_node("AbilitySystemComponent")
	# 属性集配在场景的 ASC 节点上，入树时框架已经深拷贝好；这里只写初始数值
	_init_attributes()
	_apply_passive_effects(passive_effects)

	brain = get_node("BattleBrain")
	brain.unit = self
	# 场景里的能力节点挂在 ASC 下，入树时已经由框架自动授予；
	# 这里只把它们登记给大脑，供每帧轮询
	for child in asc.get_children():
		if child is GameplayAbility:
			brain.abilities.append(child as GameplayAbility)
	# 场景配置的魂灵 → 技能（玩家场景 souls 为空，由 BattleWindow 从装备读取后调用）
	add_soul_abilities(souls)

	var health_bar := get_node_or_null("HealthBar") as UnitHealthBar
	if health_bar != null:
		health_bar.bind(health_attr, max_health_attr, asc, _bar_color())

	# 头顶名字：场景里有 Name 标签就跟着 unit_name 走
	var name_label := get_node_or_null("Name") as Label
	if name_label != null:
		name_label.text = unit_name

	_connect_asc()


## ASC 入树之后写初始属性：先设上限，血量的钳制依赖它
func _init_attributes() -> void:
	asc.get_attribute("max_health").base_value = max_health
	asc.get_attribute("health").base_value = max_health

	health_attr = asc.get_attribute("health")
	max_health_attr = asc.get_attribute("max_health")

	# 阵营标签（本案例逻辑以 team 字段为准；标签留给未来的标签过滤器用）
	asc.add_tag(GameplayTags.Team_Player if team == Team.PLAYER else GameplayTags.Team_Enemy)


## 开战前挂被动效果。上限变化时按原生命百分比同步当前生命。
## 此时还没 _connect_asc()，也还没 bind 血条，所以不会产生状态日志。
func _apply_passive_effects(effects: Array[GameplayEffect]) -> void:
	if effects.is_empty():
		return
	var health_ratio := health_attr.current_value / maxf(max_health_attr.current_value, 0.001)
	var max_before := max_health_attr.current_value
	for effect in effects:
		if effect != null:
			# 被动效果不写“获得/结束状态”日志
			effect.set_meta("passive", true)
			asc.apply_gameplay_effect(effect, asc)
	if not is_equal_approx(max_before, max_health_attr.current_value):
		# 走 ASC 的钳制和重算；此时还未连接日志/血条，不会产生开场飘字
		var target_health := max_health_attr.current_value * health_ratio
		var health_delta := target_health - health_attr.current_value
		if not is_zero_approx(health_delta):
			asc._apply_attribute_change("health", health_delta)


## 把一批魂灵变成技能；返回与输入等长的能力数组，null 表示这颗魂灵没有技能。
func add_soul_abilities(soul_list: Array[SoulData]) -> Array[AutoCastAbility]:
	var result : Array[AutoCastAbility] = []
	for i in soul_list.size():
		var soul := soul_list[i]
		result.append(null)
		if soul == null or soul is PassiveSoulData or soul.skill == null:
			continue
		var ability := AutoCastAbility.new()
		ability.apply_definition(soul.skill, soul.item_name)
		brain.add_ability(ability)
		result[i] = ability
	return result


func _connect_asc() -> void:
	asc.attribute_changed.connect(_on_attribute_changed)
	asc.active_effect_added.connect(_on_active_effect_added)
	asc.active_effect_removed.connect(_on_active_effect_removed)
	asc.effect_received.connect(_on_effect_received)


## 血条颜色：敌红我绿
func _bar_color() -> Color:
	return Color(0.40, 0.85, 0.45) if team == Team.PLAYER else Color(0.90, 0.30, 0.25)


## 放到某个格子上（瞬时）
func set_cell(p_cell: Vector2i) -> void:
	cell = p_cell
	position = battle.cell_to_world(p_cell)


## 挪到相邻格：逻辑立刻到位（选目标马上就按新位置算），视觉用补间追过去
func move_to_cell(p_cell: Vector2i) -> void:
	cell = p_cell
	create_tween().tween_property(self, "position", battle.cell_to_world(p_cell), 0.15)


## 血量百分比（0~1），TargetRule 的 LOWEST_HP_PERCENT 规则用它排序
func health_percent() -> float:
	return health_attr.current_value / maxf(max_health_attr.current_value, 0.001)


#region 观战日志与死亡
func _log(text: String, color: String = "white") -> void:
	if battle:
		battle.log_line(text, color)


## 血条和死亡只看属性变化；伤害/治疗叙事走 effect_received。
func _on_attribute_changed(attribute_name: String, _old_value: float, new_value: float, _spec: GameplayEffectSpec) -> void:
	if attribute_name == "health" and new_value <= 0.0:
		_queue_death()


## 效果生命周期：只有对方真正收到效果时才写伤害/治疗日志和飘字。
## 击杀那一下也要显示，所以这里不因为 is_dead 直接返回。
func _on_effect_received(_source_asc: AbilitySystemComponent, spec: GameplayEffectSpec) -> void:
	if spec == null:
		return
	if spec.effect_def != null and bool(spec.effect_def.get_meta("passive", false)):
		return
	var delta := float(spec.calculated_deltas.get("health", 0.0))
	if is_zero_approx(delta):
		return

	var current := health_attr.current_value
	var old_value := current - delta
	var source_name := "未知来源"
	if spec.context and spec.context.instigator is BattleUnit:
		source_name = (spec.context.instigator as BattleUnit).unit_name
	var effect_name := "未知效果"
	if spec.effect_def and spec.effect_def.resource_name != "":
		effect_name = spec.effect_def.resource_name
	var critical := spec.has_tag(GameplayTags.Event_Combat_Critical)
	var crit_suffix := "（暴击）" if critical else ""

	if delta < 0.0:
		_log("%s 受到【%s】（来自 %s）%.0f 点伤害%s，HP %.0f → %.0f"
			% [unit_name, effect_name, source_name, -delta, crit_suffix, old_value, current], "#ff6e6e")
		_pop_number(-delta, false, critical)
	elif delta > 0.0:
		_log("%s 回复 %.0f 点生命%s，HP %.0f → %.0f"
			% [unit_name, delta, crit_suffix, old_value, current], "#7ddf7d")
		_pop_number(delta, true, critical)


## 头顶跳一个数字
func _pop_number(amount: float, heal: bool, critical: bool = false) -> void:
	var number := DamageNumber.new()
	add_child(number)  # 先入树，里面建补间要用
	number.setup(amount, heal, critical)


## 延迟一帧确认死亡：先让 effect_received 写伤害日志，再写“倒下”；
## 同帧内又被治疗回正的话就不死。
func _queue_death() -> void:
	if _death_queued:
		return
	_death_queued = true
	_die_deferred.call_deferred()


func _die_deferred() -> void:
	_death_queued = false
	if is_dead or health_attr == null or health_attr.current_value > 0.0:
		return
	_die()


## 销毁单位前调用：停技能、清 active effects，避免 GAS 泄漏。
func cleanup_asc() -> void:
	if asc != null:
		asc.cleanup()


func _on_active_effect_added(active_effect: ActiveGameplayEffect) -> void:
	var def := active_effect.get_effect_def()
	if is_dead or def == null or def.policy == GameplayEffect.DurationPolicy.INSTANT or bool(def.get_meta("passive", false)):
		return
	_log("%s 获得状态【%s】（%.1f 秒）" % [unit_name, def.resource_name, active_effect.time_remaining], "#57d9e8")


func _on_active_effect_removed(active_effect: ActiveGameplayEffect) -> void:
	var def := active_effect.get_effect_def()
	if is_dead or def == null or def.policy == GameplayEffect.DurationPolicy.INSTANT or bool(def.get_meta("passive", false)):
		return
	_log("%s 的状态【%s】结束" % [unit_name, def.resource_name], "gray")


func _die() -> void:
	is_dead = true
	asc.add_tag(GameplayTags.State_Dead)
	if brain != null:
		brain.set_process(false)
		brain.set_physics_process(false)
	_log("%s 倒下了！" % unit_name, "#ffcc44")
	died.emit(self)
#endregion
