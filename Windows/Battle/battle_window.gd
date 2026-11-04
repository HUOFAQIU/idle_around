class_name BattleWindow
extends BaseWindow

## 角色倒下后多久重开一整场
const REVIVE_DELAY : float = 3.0

## 特殊怪：不参与常规随机刷怪，每击杀 RARE_SPAWN_EVERY_KILLS 只常规怪后刷一只
const RARE_MONSTER_ID : StringName = &"fu_data"
const RARE_SPAWN_EVERY_KILLS : int = 10

## 玩家单位：配置好的场景，开战时直接实例化
const PLAYER_SCENE := preload("res://game/content/Player/player.tscn")

## 魂灵窗口里那四个格子（容器名，见 equipment_window.tscn）
const SOUL_SLOT_NAMES : Array[String] = ["cell_0", "cell_1", "cell_2", "cell_3"]

## 格子上画距离数字（调试用）
const SHOW_DEBUG_DISTANCE : bool = false
## FPS 文本刷新间隔（渲染帧）
const FPS_UPDATE_FRAMES : int = 15

@onready var ground_tilemaplayer: TileMapLayer = $Tile/GroundTileMapLayer
## 单位的家：跟地图同一个坐标系，所以单位直接挂这儿
@onready var units_root: Node2D = $Tile/Units

@onready var player_health_bar: PlayerHealthBar = $CanvasLayer/Control/PlayerHealthBar
@onready var player_regen_bar: PlayerStatusBar = $CanvasLayer/Control/PlayerRegenBar
@onready var player_shield_bar: PlayerStatusBar = $CanvasLayer/Control/PlayerShieldBar
@onready var player_burn_bar: PlayerStatusBar = $CanvasLayer/Control/PlayerBurnBar
@onready var player_poison_bar: PlayerStatusBar = $CanvasLayer/Control/PlayerPoisonBar
@onready var info_button: Button = $CanvasLayer/Control/GridContainer/InfoButton
@onready var start_button: Button = $CanvasLayer/Control/GridContainer/StartButton
@onready var fps_label: Label = $CanvasLayer/Control/FpsLabel

## 现在这一场。开打时建，关窗/重开时整个销毁 —— 单位的属性、标签、冷却
## 全挂在它下面的节点上，所以销毁就等于全清，不用写复原逻辑
var _battle : BattleManager
## 重开代次：角色倒下要等 3 秒，这期间玩家自己点了重开的话，那次等待作废
var _run_id : int = 0
## 测试接口：下一次刷怪强制使用这个 ID，刷出后清空
var _test_monster_id : StringName = &""
## 常规怪击杀计数；每满 RARE_SPAWN_EVERY_KILLS，排队一只蝮
var _normal_kills : int = 0
## 已排队、等下一拍刷出的蝮数量
var _pending_rare_spawns : int = 0
## FPS 文本刷新计数
var _fps_frames : int = 0
## 这一场参战的魂灵（开打时从装备格里抓的，用来推扫描线）
var _battle_souls : Array[SoulData] = []
## 与 _battle_souls 同下标：魂灵在装备栏里的位置（左右/触发顺序用）
var _battle_slots : Array[SoulSlot] = []
## 与 _battle_souls 同下标：每颗魂灵对应的技能（没有技能为 null）
var _soul_abilities : Array[AutoCastAbility] = []
## 上一帧鼠标在不在本窗口里（用来判断"刚离开"这一下）
var _mouse_was_inside : bool = false


func _ready() -> void:
	super()
	title = "战斗窗口"
	player_health_bar.visible = false
	player_regen_bar.visible = false
	player_shield_bar.visible = false
	player_burn_bar.visible = false
	player_poison_bar.visible = false
	# 场景只负责布局；文字颜色统一由 GameColors 提供
	$CanvasLayer/Control.theme = GameColors.build_label_theme()
	fps_label.add_theme_color_override("font_outline_color", GameColors.to_color(GameColors.TEXT_OUTLINE))
	fps_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.SUCCESS))
	_apply_status_bar_colors()

	# ☰ 开关战斗信息窗口；▶ 才是开战
	info_button.pressed.connect(_on_info_pressed)
	start_button.pressed.connect(_start_battle)

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
				label.add_theme_color_override("font_color", GameColors.to_color(GameColors.TEXT_PRIMARY))
			else:
				label.add_theme_color_override("font_color", GameColors.to_color(GameColors.TEXT_OUTLINE))
			label.text = str(d)
			ground_tilemaplayer.add_child(label)


func _process(_delta: float) -> void:
	# 窗口没开着就不统计
	if not visible:
		return

	_fps_frames += 1
	if _fps_frames % FPS_UPDATE_FRAMES != 0:
		return

	var fps := Engine.get_frames_per_second()
	fps_label.text = "FPS %d" % fps
	fps_label.add_theme_color_override("font_color", _fps_color(fps))


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
	_battle_slots = _equipped_souls()
	_battle_souls.clear()
	for slot in _battle_slots:
		_battle_souls.append(slot.soul)
	_battle.player = _spawn_player(_battle_slots)
	CombatTelemetry.begin_run(_run_id, _battle, _battle.player.loadout)
	CombatTelemetry.watch_unit(_battle.player)
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
	CombatTelemetry.end_run("clear")
	_normal_kills = 0
	_pending_rare_spawns = 0
	player_health_bar.visible = false
	player_regen_bar.visible = false
	player_shield_bar.visible = false
	player_burn_bar.visible = false
	player_poison_bar.visible = false
	SoulRuntimeDB.clear()
	_soul_abilities.clear()
	_battle_slots.clear()
	for child in units_root.get_children():
		if child is BattleUnit:
			(child as BattleUnit).cleanup_asc()
		child.queue_free()
	if _battle:
		_battle.queue_free()
		_battle = null


# 角色：站在战场中心，技能全部来自装备上的魂灵
# 注意是"一颗魂灵一个技能"：同一颗魂灵装两把也要各算各的冷却，不能去重
func _spawn_player(slots: Array[SoulSlot]) -> BattleUnit:
	var passive_effects: Array[GameplayEffect] = []
	for slot in slots:
		var passive := slot.soul as PassiveSoulData
		if passive == null:
			continue
		for effect in passive.passive_effects:
			if effect != null:
				passive_effects.append(effect)

	var unit := PLAYER_SCENE.instantiate() as BattleUnit
	units_root.add_child(unit)
	unit.setup_from_scene(_battle, passive_effects)
	unit.set_cell(Vector2i.ZERO)
	unit.died.connect(_on_player_died)
	_battle.add_unit(unit)
	player_health_bar.bind(unit.health_attr, unit.max_health_attr, unit.asc)
	player_health_bar.visible = true
	player_regen_bar.bind(unit.asc.get_attribute("regen"), unit.asc)
	player_shield_bar.bind(unit.shield_attr, unit.asc)
	player_burn_bar.bind(unit.asc.get_attribute("burn"), unit.asc)
	player_poison_bar.bind(unit.asc.get_attribute("poison"), unit.asc)

	# 魂灵 → 技能 + 运行期状态：和怪物走同一条管线；
	# slots 传进去后由 BattleUnit 统一写技能位置并建 SoulRuntime
	_soul_abilities = unit.add_soul_abilities(_battle_souls, slots)

	var granted := 0
	for ability in _soul_abilities:
		if ability != null:
			granted += 1
	if granted == 0:
		_battle.log_line("没有装备主动魂灵 —— 角色不会任何技能", "yellow")

	return unit


# 怪物：场景只负责战斗表现，选哪只怪由刷怪规则决定
func _spawn_enemy(cell: Vector2i) -> void:
	var monster := _pick_monster_for_spawn()
	if monster == null:
		return
	var unit := monster.battle_scene.instantiate() as BattleUnit
	if unit == null:
		push_warning("见闻：怪物场景根节点不是 BattleUnit")
		return
	unit.unit_name = monster.display_name
	unit.max_health = monster.max_health
	unit.drops = monster.drop_entries()
	unit.souls = monster.soul_list()
	units_root.add_child(unit)
	unit.setup_from_scene(_battle)
	unit.set_cell(cell)
	# 同一格刷出来的怪加一点随机偏移，避免完全重叠；碰撞体负责其余的推开
	unit.position += Vector2.from_angle(_battle.rng.randf() * TAU) * _battle.rng.randf_range(0.0, 12.0)
	_battle.add_unit(unit)
	unit.died.connect(_on_enemy_died.bind(monster))
	CollectionDB.mark_monster_seen(monster)


## 选怪优先级：测试强制 ID > 已排队的蝮 > 常规随机池
func _pick_monster_for_spawn() -> MonsterData:
	if not _test_monster_id.is_empty():
		var forced := CollectionDB.get_monster(_test_monster_id)
		_test_monster_id = &""
		return forced
	if _pending_rare_spawns > 0:
		var rare := CollectionDB.get_monster(RARE_MONSTER_ID)
		if rare != null:
			_pending_rare_spawns -= 1
			return rare
	return CollectionDB.pick_random_monster()


## 常规怪死亡计数；每满阈值，把下一只刷怪换成蝮
func _on_enemy_died(_unit: BattleUnit, monster: MonsterData) -> void:
	if _battle == null or not _battle.is_running:
		return
	if monster == null or monster.spawn_weight <= 0.0:
		return
	_normal_kills += 1
	if _normal_kills < RARE_SPAWN_EVERY_KILLS:
		return
	_normal_kills -= RARE_SPAWN_EVERY_KILLS
	_pending_rare_spawns += 1


## 装备着的魂灵：魂灵窗口里那四个格子，每个其实是一个只收 SOUL 的小背包。
## 返回按“部位行从上到下、行内从左到右”排好的位置信息。
func _equipped_souls() -> Array[SoulSlot]:
	var slots : Array[SoulSlot] = []
	for slot_name in SOUL_SLOT_NAMES:
		var container := ContainerRepository.instance.get_container(slot_name)
		if container == null:
			continue
		var row_slots : Array[SoulSlot] = []
		for item in container.items:
			if not item is SoulData:
				continue
			var grids := container.find_grids_by_item_data(item)
			if grids.is_empty():
				continue
			var column := grids[0].x
			for grid in grids:
				column = mini(column, grid.x)
			var soul := item as SoulData
			var slot := SoulSlot.new()
			slot.soul = soul
			slot.container_name = slot_name
			slot.column = column
			slot.width = maxi(soul.columns, 1)
			row_slots.append(slot)
		row_slots.sort_custom(func (a: SoulSlot, b: SoulSlot) -> bool: return a.column < b.column)
		slots.append_array(row_slots)
	return slots


#region 魂灵扫描线 = 冷却条

## 每帧把每颗魂灵的冷却进度/状态写进 SoulRuntime；
## ItemView 监听 runtime.changed 更新材质和徽章，不再往 SoulData 里写运行期状态。
func _push_scanlines() -> void:
	if _battle == null or _battle.player == null:
		return
	for runtime in _battle.player.loadout:
		if runtime != null:
			runtime.refresh_from_ability()


## 扫描线的总开关：不在战斗时整条收起来（这是文档要的"战斗开始后才出现"）
## 被动魂灵没有冷却，不显示扫描线。
func _set_scanlines(on: bool) -> void:
	for i in _battle_souls.size():
		var soul := _battle_souls[i]
		var has_active := i < _soul_abilities.size() and _soul_abilities[i] != null
		soul.set_scanline_enabled(on and has_active)
	if not on and _battle != null and _battle.player != null:
		for runtime in _battle.player.loadout:
			if runtime != null:
				runtime.clear_display()
	elif on:
		_push_scanlines()
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
		if TooltipWindow.instance != null:
			TooltipWindow.instance.hide_tip(self)
		_end_battle()


func _on_info_pressed() -> void:
	InfoWindow.instance.toggle()


# 跟着鼠标显示 hover 到的格子：距离中心的格数 + 格子坐标
func _update_coord_tooltip() -> void:
	var tip := TooltipWindow.instance
	if tip == null:
		return

	# 只有战斗窗口自己拥有焦点时才显示坐标。魂灵窗口盖在上面时，
	# 它的物品 tooltip 优先级更高，这里不能再抢。
	if not has_focus():
		_mouse_was_inside = false
		tip.hide_tip(self)
		return

	# 鼠标不在这个窗口里就彻底撒手：tooltip 是全游戏共用一个，
	# 魂灵窗口 hover 物品时正用着它，这里每帧无条件 show/hide 会把人家盖掉。
	# 只在"刚离开"那一帧收一次，之后就什么都不做
	if not _is_mouse_inside():
		if _mouse_was_inside:
			_mouse_was_inside = false
			tip.hide_tip(self)
		return
	_mouse_was_inside = true

	# 鼠标在 TileMapLayer 局部坐标系中的位置
	var local_mouse := ground_tilemaplayer.get_local_mouse_position()
	# 鼠标所指的格子
	var hovered_cell := ground_tilemaplayer.local_to_map(local_mouse)
	# 鼠标不在有效图块上 -> 收起提示
	if ground_tilemaplayer.get_cell_source_id(hovered_cell) == -1:
		tip.hide_tip(self)
		return
	tip.show_tip(self, TooltipWindow.Layer.COORD, str(hovered_cell))


# 鼠标在不在本窗口的屏幕范围里（窗口是独立 OS 窗口，所以拿屏幕坐标比）
func _is_mouse_inside() -> bool:
	return Rect2i(position, size).has_point(DisplayServer.mouse_get_position())


## 状态条和状态名标签统一从 GameColors 取色
func _apply_status_bar_colors() -> void:
	_apply_status_color(player_regen_bar, "RegenLabel", GameColors.REGEN)
	_apply_status_color(player_shield_bar, "ShieldLabel", GameColors.SHIELD)
	_apply_status_color(player_burn_bar, "BurnLabel", GameColors.BURN)
	_apply_status_color(player_poison_bar, "PoisonLabel", GameColors.POISON)


func _apply_status_color(bar: PlayerStatusBar, label_name: String, hex: String) -> void:
	var color := GameColors.to_color(hex)
	bar.fill_color = color
	var label := bar.get_node_or_null(label_name) as Label
	if label != null:
		label.add_theme_color_override("font_color", color)


# FPS 颜色：绿 / 黄 / 红
func _fps_color(fps : int) -> Color:
	if fps >= 55:
		return GameColors.to_color(GameColors.SUCCESS)
	if fps >= 30:
		return GameColors.to_color(GameColors.WARNING)
	return GameColors.to_color(GameColors.DANGER)


#region 测试接口（TestAPI 调用）

## 测试：开战；monster_id 非空时首只必刷该怪
func start_battle_for_test(monster_id : StringName = &"") -> void:
	_test_monster_id = monster_id
	_start_battle()


## 测试：结束当前战斗
func stop_battle_for_test() -> void:
	_end_battle()


## 测试：立刻在远处空位刷一只指定怪物
func spawn_monster_for_test(monster_id : StringName) -> bool:
	if _battle == null or not _battle.is_running:
		return false
	if CollectionDB.get_monster(monster_id) == null:
		return false
	var before := _battle.units.size()
	_test_monster_id = monster_id
	_battle.spawn_one()
	if _battle.units.size() > before:
		return true
	_test_monster_id = &""
	return false


## 测试：当前战斗快照；没有战斗时 running = false
func get_test_state() -> Dictionary:
	var state := {
		"running": false,
		"elapsed": 0.0,
		"player": {},
		"enemies": [],
		"player_souls": [],
		"normal_kills": _normal_kills,
		"pending_rare_spawns": _pending_rare_spawns,
	}
	if _battle == null:
		return state

	state["running"] = _battle.is_running
	state["elapsed"] = _battle.elapsed_seconds()
	state["player"] = _unit_test_state(_battle.player)

	var enemies : Array = []
	for unit in _battle.units:
		if unit != _battle.player:
			enemies.append(_unit_test_state(unit))
	state["enemies"] = enemies

	var souls : Array = []
	for i in _battle_souls.size():
		var soul := _battle_souls[i]
		var ability : AutoCastAbility = null
		if i < _soul_abilities.size():
			ability = _soul_abilities[i]
		souls.append({
			"name": soul.item_name,
			"cooldown": ability.cooldown if ability != null else 0.0,
			"charge_ratio": ability.charge_ratio() if ability != null else 0.0,
			"charge_seconds": ability.charge_seconds() if ability != null else 0.0,
			"haste": ability.haste_seconds() if ability != null else 0.0,
			"slow": ability.slow_seconds() if ability != null else 0.0,
			"freeze": ability.freeze_seconds() if ability != null else 0.0,
			"frozen": ability.is_frozen() if ability != null else false,
			"active": ability.is_active if ability != null else false,
			"activation_lock": ability.activation_lock_seconds() if ability != null else 0.0,
		})
	state["player_souls"] = souls
	return state


## 测试：战斗窗口右上角的 FPS 文本
func get_fps_text_for_test() -> String:
	return fps_label.text


func _unit_test_state(unit : BattleUnit) -> Dictionary:
	if unit == null:
		return {}
	var soul_names : Array[String] = []
	for soul in unit.souls:
		if soul != null:
			soul_names.append(soul.item_name)
	var regen_attr := unit.asc.get_attribute("regen") if unit.asc != null else null
	var poison_attr := unit.asc.get_attribute("poison") if unit.asc != null else null
	var distance_to_player := -1.0
	var in_attack_range := false
	if _battle != null and _battle.player != null:
		distance_to_player = unit.distance_to_unit(_battle.player)
		in_attack_range = unit.team == BattleUnit.Team.ENEMY and unit.is_in_attack_range(_battle.player)
	return {
		"name": unit.unit_name,
		"hp": unit.health_attr.current_value if unit.health_attr != null else 0.0,
		"max_hp": unit.max_health_attr.current_value if unit.max_health_attr != null else 0.0,
		"shield": unit.shield_attr.current_value if unit.shield_attr != null else 0.0,
		"regen": regen_attr.current_value if regen_attr != null else 0.0,
		"poison": poison_attr.current_value if poison_attr != null else 0.0,
		"dead": unit.is_dead,
		"frozen": unit.asc.has_tag(GameplayTags.State_Frozen) if unit.asc != null else false,
		"cell": [unit.cell.x, unit.cell.y],
		"position": [unit.position.x, unit.position.y],
		"distance_to_player": distance_to_player,
		"in_attack_range": in_attack_range,
		"souls": soul_names,
	}

#endregion
