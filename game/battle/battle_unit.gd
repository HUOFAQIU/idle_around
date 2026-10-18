## 战斗单位：战场上的一个 token，逻辑和表现都在它身上。
##
## 节点结构（有框架强约束）：
##   BattleUnit (Node2D)          ← 位置跟着 cell 走
##   ├── Sprite2D                 ← 本体（token 图）
##   ├── UnitHealthBar            ← 头顶血条
##   ├── AbilitySystemComponent   ← 名字必须精确叫这个！
##                                   框架在解析"施法者→ASC"时用的是
##                                   get_node_or_null("AbilitySystemComponent")
##   └── BattleBrain              ← 自动施法
##
## 位置：cell 是逻辑坐标（选目标、寻路都算它），position 是像素投影，
## 由 BattleManager.cell_to_world() 换算 —— 战斗逻辑不依赖地图节点。

class_name BattleUnit extends Node2D

## 单位倒下时发出
signal died(unit: BattleUnit)

enum Team { PLAYER, ENEMY }

## 血条浮在头顶多高
const HEALTH_BAR_OFFSET := Vector2(0.0, -26.0)
## 挪一格的视觉时长：cell 立刻变，画面用补间追上来
const MOVE_TIME := 0.15

@export var unit_name: String = ""
@export var team: Team = Team.PLAYER
## 血量上限（场景配置的单位用；代码建号时由 setup 的参数覆盖）
@export var max_health: float = 100.0
## 场景建号时用哪个属性集脚本（默认怪物属性集，玩家场景覆盖成玩家属性集）
@export var attribute_set_script: Script = preload("res://godot_gas/attributes/monster_stats_attribute_set.gd")

var battle: BattleManager
var asc: AbilitySystemComponent
var brain: BattleBrain
var is_dead: bool = false

## 战场格子坐标（逻辑位置）
var cell: Vector2i = Vector2i.ZERO

## 缓存（ASC _ready 会深拷贝属性集，所以要在 add_child 之后再取引用）
var health_attr: AttributeData
var max_health_attr: AttributeData

var _body: Sprite2D
var _health_bar: UnitHealthBar


## 建号（代码构建：ASC / 大脑 / 外观都在这里 new）。
## 调用前请先把本节点 add_child 进场景树。
func setup(p_name: String, p_team: Team, p_max_health: float, skills: Array[SkillDefinition], p_battle: BattleManager) -> void:
	unit_name = p_name
	team = p_team
	battle = p_battle
	
	# 1. 属性集（数值先留默认，第 2 步说明为什么）
	var stats := PlayerStatsAttributeSet.new()
	
	# 2. ASC（框架会在 _ready 里对属性集做 duplicate(true) 深拷贝，保证每个单位内存独立。
	#    注意：duplicate 只复制带 STORAGE 标记的属性（即 @export 的），属性集里的普通
	#    var 在入树前被赋的运行时值不会随深拷贝保留。所以初始数值必须在 ASC 入树之后、
	#    通过 ASC 写进那份"活"的属性集里 —— 这也正是框架推荐的属性修改路径。
	asc = AbilitySystemComponent.new()
	asc.name = "AbilitySystemComponent"
	asc.attribute_sets.append(stats)
	add_child(asc)

	_init_attributes(p_max_health)

	# 3. 自动施法大脑
	brain = BattleBrain.new()
	brain.name = "BattleBrain"
	add_child(brain)
	brain.setup(self, skills)

	# 4. 接线：观战日志与死亡
	_connect_asc()


## 从场景建号：ASC、外观、能力都由场景预先配置。
## 场景根节点已经入树（子节点的 _ready 跑过）之后调用。
func setup_from_scene(p_battle: BattleManager) -> void:
	battle = p_battle

	asc = get_node("AbilitySystemComponent")
	# ASC 的 _ready 已经在入树时跑过，属性集在这里补一份；get_attribute 是实时遍历，
	# 补进来即可用，而且这份实例只属于本单位
	asc.attribute_sets.append(attribute_set_script.new() as AttributeSet)
	_init_attributes(max_health)

	brain = get_node("BattleBrain")
	brain.unit = self
	# 场景里的能力节点挂在 ASC 下，入树时已经由框架自动授予；
	# 这里只把它们登记给大脑，供每帧轮询
	for child in asc.get_children():
		if child is GameplayAbility:
			brain.abilities.append(child as GameplayAbility)

	_body = get_node("Body")
	_health_bar = get_node("HealthBar")
	_health_bar.bind(health_attr, max_health_attr, asc, _bar_color())

	# 头顶名字：场景里有 Name 标签就跟着 unit_name 走
	var name_label := get_node_or_null("Name") as Label
	if name_label != null:
		name_label.text = unit_name

	_connect_asc()


## ASC 入树之后写初始属性：先设上限，血量的钳制依赖它
func _init_attributes(p_max_health: float) -> void:
	asc.get_attribute("max_health").base_value = p_max_health
	asc.get_attribute("health").base_value = p_max_health

	health_attr = asc.get_attribute("health")
	max_health_attr = asc.get_attribute("max_health")

	# 阵营标签（本案例逻辑以 team 字段为准；标签留给未来的标签过滤器用）
	asc.add_tag(GameplayTags.Team_Player if team == Team.PLAYER else GameplayTags.Team_Enemy)


func _connect_asc() -> void:
	asc.attribute_changed.connect(_on_attribute_changed)
	asc.active_effect_added.connect(_on_active_effect_added)
	asc.active_effect_removed.connect(_on_active_effect_removed)


## 外观：从贴图里抠一块当本体，顺便把头顶血条挂上。放在 setup 之后调。
func set_body(texture: Texture2D, region: Rect2, color: Color) -> void:
	_body = Sprite2D.new()
	_body.texture = texture
	_body.region_enabled = true
	_body.region_rect = region
	_body.modulate = color
	add_child(_body)

	_health_bar = UnitHealthBar.new()
	_health_bar.position = HEALTH_BAR_OFFSET
	add_child(_health_bar)
	_health_bar.bind(health_attr, max_health_attr, asc, _bar_color())


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
	create_tween().tween_property(self, "position", battle.cell_to_world(p_cell), MOVE_TIME)


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

	_update_wounded_tag(new_value)

	if new_value <= 0.0:
		_die()


## 头顶跳一个数字
func _pop_number(amount: float, heal: bool) -> void:
	var number := DamageNumber.new()
	add_child(number)  # 先入树，里面建补间要用
	number.setup(amount, heal)


## "受伤"状态维护：血量低于上限就挂 State.Wounded 标签，回满则摘掉。
## 治愈技能就是靠 activation_query 要求这个标签实现"只在受伤时施放"的。
func _update_wounded_tag(health_value: float) -> void:
	var wounded := health_value < max_health_attr.current_value and health_value > 0.0
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
