## 战斗单位：战场上的一个 token，逻辑和表现都在它身上。
##
## 节点结构（有框架强约束）：
##   BattleUnit (Node2D)          ← 位置跟着 cell 走
##   ├── AbilitySystemComponent   ← 名字必须精确叫这个！
##                                   框架在解析"施法者→ASC"时用的是
##                                   get_node_or_null("AbilitySystemComponent")
##                                   属性集配在它的 attribute_sets 上
##   ├── BattleBrain              ← 自动施法
##   ├── HealthBar (UnitHealthBar)← 血条（必需）
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

var battle: BattleManager
var asc: AbilitySystemComponent
var brain: BattleBrain
var is_dead: bool = false

## 战场格子坐标（逻辑位置）
var cell: Vector2i = Vector2i.ZERO

## 缓存（ASC _ready 会深拷贝属性集，所以要在 add_child 之后再取引用）
var health_attr: AttributeData
var max_health_attr: AttributeData


## 从场景建号：ASC、外观、能力都由场景预先配置。
## 场景根节点已经入树（子节点的 _ready 跑过）之后调用。
func setup_from_scene(p_battle: BattleManager) -> void:
	battle = p_battle

	asc = get_node("AbilitySystemComponent")
	# 属性集配在场景的 ASC 节点上，入树时框架已经深拷贝好；这里只写初始数值
	_init_attributes()

	brain = get_node("BattleBrain")
	brain.unit = self
	# 场景里的能力节点挂在 ASC 下，入树时已经由框架自动授予；
	# 这里只把它们登记给大脑，供每帧轮询
	for child in asc.get_children():
		if child is GameplayAbility:
			brain.abilities.append(child as GameplayAbility)

	var health_bar := get_node("HealthBar") as UnitHealthBar
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


func _connect_asc() -> void:
	asc.attribute_changed.connect(_on_attribute_changed)
	asc.active_effect_added.connect(_on_active_effect_added)
	asc.active_effect_removed.connect(_on_active_effect_removed)


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


## 统一的掉血/回血日志：所有属性变化（含 DoT 每秒 tick）都会经过这里。
func _on_attribute_changed(attribute_name: String, old_value: float, new_value: float, spec: GameplayEffectSpec) -> void:
	if attribute_name != "health" or is_dead:
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
		_pop_number(old_value - new_value, false)
	elif new_value > old_value:
		_log("%s 回复 %.0f 点生命，HP %.0f → %.0f"
			% [unit_name, new_value - old_value, old_value, new_value], "#7ddf7d")
		_pop_number(new_value - old_value, true)

	if new_value <= 0.0:
		_die()


## 头顶跳一个数字
func _pop_number(amount: float, heal: bool) -> void:
	var number := DamageNumber.new()
	add_child(number)  # 先入树，里面建补间要用
	number.setup(amount, heal)


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


## 蓄力等内部效果不播报（靠 State.Charging.* 标签识别）
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
