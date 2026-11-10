class_name BattleWindow
extends BaseWindow

## 容器名集中定义；用 preload 而不是全局类名，保证 --script 无头模式也能解析
const CONTAINER_IDS: GDScript = preload("res://Scripts/container_ids.gd")

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

## 本场会话：创建/销毁 BattleManager、生成单位、稀有队列、复活重开
var _session : BattleSession
## 现在这一场；TestAPI 与快照沿用旧入口，实际由会话持有
var _battle : BattleManager:
	get:
		return _session.battle if _session != null else null
## 事件总线的观察者；随这一场一起创建、一起丢弃
var _telemetry_adapter : CombatTelemetryAdapter
var _info_log_adapter : BattleLogAdapter
var _console_log_adapter : CombatConsoleAdapter
## FPS 文本刷新计数
var _fps_frames : int = 0
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

	# 会话负责战斗生命周期与生成逻辑；窗口只响应信号更新 UI
	_session = BattleSession.new()
	_session.name = "BattleSession"
	add_child(_session)
	_session.units_root = units_root
	_session.map = ground_tilemaplayer
	_session.attach_observers = _attach_battle_observers
	_session.battle_started.connect(_on_battle_started)
	_session.battle_ended.connect(_on_battle_ended)
	_session.player_spawned.connect(_on_player_spawned)

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
func _start_battle(monster_id : StringName = &"") -> void:
	InfoWindow.instance.clear_log()
	_session.start(_equipped_souls(), monster_id)


## 事件总线的观察者：遥测、战斗信息窗、控制台。
## 会话在生成单位之前调用，保证不漏 unit_asc_ready 与首批战斗事件。
func _attach_battle_observers(battle: BattleManager) -> void:
	_telemetry_adapter = CombatTelemetryAdapter.new(battle.events)
	_info_log_adapter = BattleLogAdapter.new(battle.events, InfoWindow.instance.append_line)
	_console_log_adapter = CombatConsoleAdapter.new(battle.events)


func _on_battle_started(_battle_manager: BattleManager) -> void:
	_set_scanlines(true)
	start_button.text = "重开"


func _on_battle_ended() -> void:
	_telemetry_adapter = null
	_info_log_adapter = null
	_console_log_adapter = null
	player_health_bar.visible = false
	player_regen_bar.visible = false
	player_shield_bar.visible = false
	player_burn_bar.visible = false
	player_poison_bar.visible = false
	_set_scanlines(false)
	start_button.text = "▷"


## 玩家生成后由窗口绑血条；会话不碰 UI
func _on_player_spawned(unit: BattleUnit) -> void:
	player_health_bar.bind(unit.health_attr, unit.max_health_attr, unit.asc)
	player_health_bar.visible = true
	player_regen_bar.bind(unit.asc.get_attribute("regen"), unit.asc)
	player_shield_bar.bind(unit.shield_attr, unit.asc)
	player_burn_bar.bind(unit.asc.get_attribute("burn"), unit.asc)
	player_poison_bar.bind(unit.asc.get_attribute("poison"), unit.asc)


# 关窗＝这场战斗结束。下次打开窗口看到的，就是这一关的初始状态
func _end_battle() -> void:
	_session.stop()


## 装备着的魂灵：魂灵窗口里那四个格子，每个其实是一个只收 SOUL 的小背包。
## 返回按“部位行从上到下、行内从左到右”排好的位置信息。
func _equipped_souls() -> Array[SoulSlot]:
	var slots : Array[SoulSlot] = []
	for slot_name in CONTAINER_IDS.soul_cells():
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
	var player := _battle.player if _battle != null else null
	if on:
		if player == null:
			return
		for runtime in player.loadout:
			if runtime != null and runtime.soul != null:
				runtime.soul.set_scanline_enabled(runtime.ability != null)
		_push_scanlines()
		return
	# 关战/重开时 player 可能已经释放，按本场魂灵副本统一关掉
	if _session == null:
		return
	for soul in _session.souls:
		if soul != null:
			soul.set_scanline_enabled(false)
	if player != null:
		for runtime in player.loadout:
			if runtime != null:
				runtime.clear_display()
#endregion


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
	_start_battle(monster_id)


## 测试：结束当前战斗
func stop_battle_for_test() -> void:
	_end_battle()


## 测试：立刻在远处空位刷一只指定怪物
func spawn_monster_for_test(monster_id : StringName) -> bool:
	return _session.spawn_monster_for_test(monster_id)


## 测试：当前战斗快照；没有战斗时 running = false
func get_test_state() -> Dictionary:
	if _session == null:
		return {
			"running": false,
			"elapsed": 0.0,
			"player": {},
			"enemies": [],
			"player_souls": [],
			"normal_kills": 0,
			"pending_rare_spawns": 0,
		}
	return _session.get_state()


## 测试：战斗窗口右上角的 FPS 文本
func get_fps_text_for_test() -> String:
	return fps_label.text

#endregion
