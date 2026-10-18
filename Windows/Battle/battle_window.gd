class_name BattleWindow
extends BaseWindow

## 角色的血量上限（角色目前只有血量这一个属性）
const PLAYER_MAX_HEALTH : float = 500.0
## 角色倒下后多久重开一整场
const REVIVE_DELAY : float = 3.0

## 单位的贴图与取哪一格
const TOKENS_TEXTURE := preload("res://Assets/tokens.png")
const PLAYER_REGION := Rect2(32, 0, 32, 32)
const PLAYER_COLOR := Color(0, 0.8765176, 0.32171732)

## 蛇：配置好的单位场景
const SNAKE_SCENE := preload("res://game/content/Monster/snake.tscn")

## 魂灵窗口里那四个格子（容器名，见 equipment_window.tscn）
const SOUL_SLOT_NAMES : Array[String] = ["cell_0", "cell_1", "cell_2", "cell_3"]

## 格子上画距离数字（调试用）
const SHOW_DEBUG_DISTANCE : bool = false

@onready var tile: Node2D = $Tile
@onready var ground_tilemaplayer: TileMapLayer = $Tile/GroundTileMapLayer
## 单位的家：跟地图同一个坐标系，所以单位直接挂这儿
@onready var units_root: Node2D = $Tile/Units

@onready var info_button: Button = $CanvasLayer/Control/GridContainer/InfoButton
@onready var start_button: Button = $CanvasLayer/Control/GridContainer/StartButton
@onready var speed_1_button: Button = $CanvasLayer/Control/GridContainer/Speed1Button
@onready var speed_2_button: Button = $CanvasLayer/Control/GridContainer/Speed2Button
@onready var speed_3_button: Button = $CanvasLayer/Control/GridContainer/Speed3Button
@onready var speed_10_button: Button = $CanvasLayer/Control/GridContainer/Speed10Button

## 现在这一场。开打时建，关窗/重开时整个销毁 —— 单位的属性、标签、冷却
## 全挂在它下面的节点上，所以销毁就等于全清，不用写复原逻辑
var _battle : BattleManager
## 重开代次：角色倒下要等 3 秒，这期间玩家自己点了重开的话，那次等待作废
var _run_id : int = 0
## 这一场参战的魂灵（开打时从装备格里抓的，用来推扫描线）
var _battle_souls : Array[SoulData] = []
## 与 _battle_souls 同下标：每颗魂灵的技能用的是哪个冷却标签（同种魂灵也各不相同）
var _soul_cooldown_tags : Array[StringName] = []
## 上一帧鼠标在不在本窗口里（用来判断"刚离开"这一下）
var _mouse_was_inside : bool = false


func _ready() -> void:
	super()
	title = "战斗窗口"

	# ☰ 开关战斗信息窗口；▶ 才是开战
	info_button.pressed.connect(_on_info_pressed)
	start_button.pressed.connect(_start_battle)
	speed_1_button.pressed.connect(
		func () :
			_apply_time_scale(1)
	)
	speed_2_button.pressed.connect(
		func () :
			_apply_time_scale(2)
	)
	speed_3_button.pressed.connect(
		func () :
			_apply_time_scale(3)
	)
	speed_10_button.pressed.connect(
		func () :
			_apply_time_scale(10)
	)

	# 关窗（标题栏 × 或主界面的切换按钮）＝ 这场战斗结束，下次打开回到初始状态
	visibility_changed.connect(_on_visibility_changed)

	if SHOW_DEBUG_DISTANCE:
		for cell in ground_tilemaplayer.get_used_cells():
			var label: Label = Label.new()
			label.size = Vector2(10, 10)
			label.add_theme_font_size_override("font_size", 12)

			var center: Vector2 = ground_tilemaplayer.map_to_local(cell)
			# Label 自身坐标是左上角，偏移一半尺寸来居中
			label.position = center - label.size / 2.0

			var d : int = Hex.distance(Vector2i(0, 0), cell)
			if d % 2 != 0:
				label.add_theme_color_override("font_color", Color.WHITE)
			else:
				label.add_theme_color_override("font_color", Color.BLACK)
			label.text = str(d)
			ground_tilemaplayer.add_child(label)


func _physics_process(_delta: float) -> void:
	# 窗口没开着就不跑
	if not visible:
		return

	_update_coord_tooltip()
	_push_scanlines()


# ---------------------------------------------------------------- 战斗

# ▶：开打。跑起来之后这个按钮是「重开」，点了就把整场推倒重来
# —— 开始和重开是同一件事：清场 + 重建
func _start_battle() -> void:
	_clear_battle()
	_run_id += 1

	_battle = BattleManager.new()
	_battle.name = "BattleManager"
	add_child(_battle)
	_battle.map = ground_tilemaplayer
	_battle.log_sink = InfoWindow.instance.append_line
	_battle.spawn_enemy = _spawn_enemy
	_battle.setup()

	InfoWindow.instance.clear_log()
	_battle_souls = _equipped_souls()
	_battle.player = _spawn_player()
	_battle.start_battle()
	# 立刻先来一只，不然点完还得对着空场等第一拍
	_battle.spawn_one()
	_set_scanlines(true)

	start_button.text = "重开"


# 关窗＝这场战斗结束。下次打开窗口看到的，就是这一关的初始状态
func _end_battle() -> void:
	_run_id += 1  # 让"等 3 秒重开"作废
	_clear_battle()
	_set_scanlines(false)
	start_button.text = "▷"


func _clear_battle() -> void:
	for child in units_root.get_children():
		child.queue_free()
	if _battle:
		_battle.queue_free()
		_battle = null


# 角色：站在战场中心，技能全部来自装备上的魂灵
# 注意是"一颗魂灵一个技能"：同一颗魂灵装两把也要各算各的冷却，不能去重
func _spawn_player() -> BattleUnit:
	var unit := BattleUnit.new()
	units_root.add_child(unit)
	var no_skills : Array[SkillDefinition] = []
	unit.setup("角色", BattleUnit.Team.PLAYER, PLAYER_MAX_HEALTH, no_skills, _battle)
	unit.set_body(TOKENS_TEXTURE, PLAYER_REGION, PLAYER_COLOR)
	unit.set_cell(Vector2i.ZERO)
	unit.died.connect(_on_player_died)
	_battle.add_unit(unit)

	# 逐个魂灵建技能，顺便给每个技能一份"自己的"冷却标签
	_soul_cooldown_tags.clear()
	var granted := 0
	for i in _battle_souls.size():
		var soul := _battle_souls[i]
		_soul_cooldown_tags.append(&"")
		if soul.skill == null:
			continue
		var ability := AutoCastAbility.new()
		ability.apply_definition(soul.skill)
		_soul_cooldown_tags[i] = _give_unique_cooldown(ability, i)
		unit.brain.add_ability(ability)
		granted += 1

	if granted == 0:
		_battle.log_line("没有装备魂灵 —— 角色不会任何技能", "yellow")

	return unit


## 给这个技能实例一份自己的冷却：复制冷却效果，标签加序号。
## 不这么做的话，同种魂灵的两个技能查的是同一个标签，会互相把对方锁在冷却里。
## 返回加了序号的标签，扫描线要靠它读剩余时间
func _give_unique_cooldown(ability: AutoCastAbility, index: int) -> StringName:
	var base := ability.skill.charge_effect
	if base == null or base.granted_tags.is_empty():
		return &""

	var charge := base.duplicate() as GameplayEffect
	var tag := StringName("%s.%d" % [base.granted_tags[0], index])
	# 浅拷贝出来的 granted_tags 和原件共用同一个 Array，必须整个换掉，不能 append
	var tags : Array[StringName] = [tag]
	charge.granted_tags = tags
	ability.cooldown_effect = charge
	return tag


# 蛇：场景里配置好的单位，直接实例化
func _spawn_enemy(cell: Vector2i) -> void:
	var unit := SNAKE_SCENE.instantiate() as BattleUnit
	units_root.add_child(unit)
	unit.setup_from_scene(_battle)
	unit.set_cell(cell)
	_battle.add_unit(unit)


## 装备着的魂灵：魂灵窗口里那四个格子，每个其实是一个只收 SOUL 的小背包
func _equipped_souls() -> Array[SoulData]:
	var souls : Array[SoulData] = []
	for slot_name in SOUL_SLOT_NAMES:
		var container := ContainerRepository.instance.get_container(slot_name)
		if container == null:
			continue
		for item in container.items:
			if item is SoulData:
				souls.append(item)
	return souls


#region 魂灵扫描线 = 冷却条

## 每帧把每颗魂灵的冷却进度写进它的扫描线（0 = 刚触发，1 = 冷却走完）
func _push_scanlines() -> void:
	if _battle == null or _battle.player == null:
		return
	for i in _battle_souls.size():
		if i >= _soul_cooldown_tags.size() or _soul_cooldown_tags[i] == &"":
			continue
		var soul := _battle_souls[i]
		soul.set_shader_param("progress", _charge_progress(soul.skill, _soul_cooldown_tags[i]))


## 冷却走完多少了。读的是框架挂在角色身上那条冷却标签的剩余时间
func _charge_progress(skill: SkillDefinition, tag: StringName) -> float:
	var effect := skill.charge_effect
	if effect == null or effect.duration <= 0.0:
		return 0.0
	var remaining := _battle.player.asc.get_tag_duration_remaining(tag)
	return clampf(1.0 - remaining / effect.duration, 0.0, 1.0)


## 扫描线的总开关：不在战斗时整条收起来（这是文档要的"战斗开始后才出现"）
func _set_scanlines(on: bool) -> void:
	for soul in _battle_souls:
		soul.set_scanline_enabled(on)
		if not on:
			soul.set_shader_param("progress", 0.0)
#endregion


# 角色倒下：停一会儿，然后整场重来
func _on_player_died(_unit: BattleUnit) -> void:
	_battle.log_line("角色倒下了，%.0f 秒后重来……" % REVIVE_DELAY, "yellow")
	var run_id := _run_id
	await get_tree().create_timer(REVIVE_DELAY).timeout
	if run_id != _run_id or not visible:
		return
	_start_battle()


# ---------------------------------------------------------------- 界面


# 关窗会走到这儿（标题栏 × 和主界面按钮最后都是 hide()）；开窗时也会走，直接放行
func _on_visibility_changed() -> void:
	if not visible:
		_end_battle()


# 加速走的是 Engine.time_scale，所以是「整个游戏一起快」，不只是这个窗口。
# 窗口关着的时候一定要还原成 1 倍，免得这个开发开关漏到游戏别的部分去。
func _apply_time_scale(speed : float) -> void:
	Engine.time_scale = speed


func _on_info_pressed() -> void:
	InfoWindow.instance.toggle()


# 跟着鼠标显示 hover 到的格子：距离中心的格数 + 格子坐标
func _update_coord_tooltip() -> void:
	# 鼠标不在这个窗口里就彻底撒手：tooltip 是全游戏共用一个，
	# 魂灵窗口 hover 物品时正用着它，这里每帧无条件 show/hide 会把人家盖掉。
	# 只在"刚离开"那一帧收一次，之后就什么都不做
	if not _is_mouse_inside():
		if _mouse_was_inside:
			_mouse_was_inside = false
			TooltipWindow.instance.hide_tip()
		return
	_mouse_was_inside = true
	
	# 鼠标在 TileMapLayer 局部坐标系中的位置
	var local_mouse := ground_tilemaplayer.get_local_mouse_position()
	# 鼠标所指的格子
	var hovered_cell := ground_tilemaplayer.local_to_map(local_mouse)
	# 鼠标不在有效图块上 -> 收起提示
	if ground_tilemaplayer.get_cell_source_id(hovered_cell) == -1:
		TooltipWindow.instance.hide_tip()
		return
	TooltipWindow.instance.show_tip()
	TooltipWindow.instance.set_window_title(str(hovered_cell))


# 鼠标在不在本窗口的屏幕范围里（窗口是独立 OS 窗口，所以拿屏幕坐标比）
func _is_mouse_inside() -> bool:
	return Rect2i(position, size).has_point(DisplayServer.mouse_get_position())
