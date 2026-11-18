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

@onready var player_health_bar: PlayerHealthBar = $UiOverlay/Control/PlayerHealthBar
@onready var player_regen_bar: PlayerStatusBar = $UiOverlay/Control/PlayerRegenBar
@onready var player_shield_bar: PlayerStatusBar = $UiOverlay/Control/PlayerShieldBar
@onready var player_burn_bar: PlayerStatusBar = $UiOverlay/Control/PlayerBurnBar
@onready var player_poison_bar: PlayerStatusBar = $UiOverlay/Control/PlayerPoisonBar
@onready var info_button: Button = $UiOverlay/Control/GridContainer/InfoButton
@onready var fps_label: Label = $UiOverlay/Control/FpsLabel

## 本场会话：创建/销毁 BattleManager、生成单位、地图刷怪、复活重开
var _session : BattleSession
## 当前战斗对应的地图；开战只从地图按钮进入
var _map_item : MapItemData
## 当前地图在地图板上的槽位；TestAPI 临时地图为 -1
var _map_slot : int = -1
## 现在这一场；TestAPI 与快照通过它读取战斗，实际由会话持有
var _battle : BattleManager:
	get:
		return _session.battle if _session != null else null
## 事件总线的观察者；随这一场一起创建、一起丢弃
var _telemetry_adapter : CombatTelemetryAdapter
var _info_log_adapter : BattleLogAdapter
var _console_log_adapter : CombatConsoleAdapter
var _narrator : CombatNarrator
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
	$UiOverlay/Control.theme = GameColors.build_label_theme()
	fps_label.add_theme_color_override("font_outline_color", GameColors.to_color(GameColors.TEXT_OUTLINE))
	fps_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.SUCCESS))
	_apply_status_bar_colors()

	# ☰ 开关战斗信息窗口；开战由 05 面的地图按钮触发
	info_button.pressed.connect(_on_info_pressed)
	MapBoard.item_removed.connect(_on_map_board_item_removed)

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
	if not visible:
		return

	_fps_frames += 1
	if _fps_frames % FPS_UPDATE_FRAMES != 0:
		return

	var fps := Engine.get_frames_per_second()
	fps_label.text = "FPS %d" % fps
	fps_label.add_theme_color_override("font_color", _fps_color(fps))


func _physics_process(_delta: float) -> void:
	if not visible:
		return

	_update_coord_tooltip()
	_push_scanlines()


# ---------------------------------------------------------------- 战斗

## 地图按钮进入：窗口显示并立刻按这张图开战；换图会清掉上一场
func start_map_battle(map_item: MapItemData, slot_index: int = -1) -> void:
	if map_item == null or map_item.map_data == null:
		return
	if not visible:
		open_window()
	_map_item = map_item
	_map_slot = slot_index
	InfoWindow.instance.clear_log()
	_session.player_profile = GameFlow.get_player_profile()
	_session.start(_equipped_souls(), map_item)


## 当前是否正在打指定槽位的地图；同一张图再次点击时只置顶
func is_battling_slot(slot_index: int) -> bool:
	return visible and _map_slot == slot_index and _map_item != null


## 流程切档/新游戏前结束当前战斗
func stop_battle() -> void:
	_end_battle()
	_map_item = null
	_map_slot = -1


## 事件总线的观察者：遥测、战斗信息窗、控制台。
## 会话在生成单位之前调用，保证不漏 unit_asc_ready 与首批战斗事件。
func _attach_battle_observers(battle: BattleManager) -> void:
	_telemetry_adapter = CombatTelemetryAdapter.new(battle.events)
	_info_log_adapter = BattleLogAdapter.new(battle.events, InfoWindow.instance.append_line)
	_console_log_adapter = CombatConsoleAdapter.new(battle.events)
	_narrator = CombatNarrator.new(battle)


func _on_battle_started(_battle_manager: BattleManager) -> void:
	_set_scanlines(true)


func _on_battle_ended() -> void:
	_telemetry_adapter = null
	_info_log_adapter = null
	_console_log_adapter = null
	_narrator = null
	player_health_bar.visible = false
	player_regen_bar.visible = false
	player_shield_bar.visible = false
	player_burn_bar.visible = false
	player_poison_bar.visible = false
	_set_scanlines(false)


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


## 装备着的魂灵：角色窗口的魂器网格，魂器按占格从上到下、从左到右，
## 魂器内部从左到右。返回按这个顺序排好的位置信息。
func _equipped_souls() -> Array[SoulSlot]:
	var slots : Array[SoulSlot] = []
	var container := ContainerRepository.instance.get_container(CONTAINER_IDS.VESSEL_GRID)
	if container == null:
		return slots
	for vessel in SoulVesselData.combat_vessels_in(container):
		var contents := vessel.ensure_contents()
		var row_slots : Array[SoulSlot] = []
		for soul_item in contents.items:
			if not soul_item is SoulData:
				continue
			var soul := soul_item as SoulData
			var grids := contents.find_grids_by_item_data(soul)
			if grids.is_empty():
				continue
			var column := ContainerData.anchor_of(grids).x
			var slot := SoulSlot.new()
			slot.soul = soul
			slot.vessel = vessel
			slot.container_name = contents.container_name
			slot.column = column
			slot.width = maxi(soul.get_shape().x, 1)
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
		_map_item = null
		_map_slot = -1


## 当前地图被 ⬇ 退回仓库：先停战再关窗
func _on_map_board_item_removed(slot_index: int) -> void:
	if slot_index == _map_slot:
		hide()


func _on_info_pressed() -> void:
	InfoWindow.instance.toggle()


# 跟着鼠标显示 hover 到的格子：距离中心的格数 + 格子坐标
func _update_coord_tooltip() -> void:
	var tip := TooltipWindow.instance
	if tip == null:
		return

	# 只有战斗窗口是激活面板、且鼠标下最上层是它时才显示坐标。
	# 仓库/魂器窗口盖在上面时，它们的物品 tooltip 优先级更高，这里不能再抢。
	var manager := PanelManager.instance
	if manager == null or not manager.is_active(self) \
			or manager.get_top_panel_at(get_global_mouse_position()) != self:
		_mouse_was_inside = false
		tip.hide_tip(self)
		return

	# 立方体是应用内最上层：指针在它的输入区时，下面的格子坐标也要让位
	var cube_surface := CubeInputSurface.instance
	if cube_surface != null \
			and cube_surface.contains_screen_point(
					get_viewport().get_mouse_position()):
		_mouse_was_inside = false
		tip.hide_tip(self)
		return

	# 鼠标不在这个窗口里就彻底撒手：tooltip 是全游戏共用一个，
	# 其他窗口 hover 物品时正用着它，这里每帧无条件 show/hide 会把人家盖掉。
	# 只在"刚离开"那一帧收一次，之后就什么都不做
	if not _is_mouse_inside():
		if _mouse_was_inside:
			_mouse_was_inside = false
			tip.hide_tip(self)
		return
	_mouse_was_inside = true

	var local_mouse := ground_tilemaplayer.get_local_mouse_position()
	var hovered_cell := ground_tilemaplayer.local_to_map(local_mouse)
	# 鼠标不在有效图块上 -> 收起提示
	if ground_tilemaplayer.get_cell_source_id(hovered_cell) == -1:
		tip.hide_tip(self)
		return
	tip.show_tip(self, TooltipWindow.Layer.COORD, str(hovered_cell))


func _is_mouse_inside() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


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
func _fps_color(fps : float) -> Color:
	if fps >= 55:
		return GameColors.to_color(GameColors.SUCCESS)
	if fps >= 30:
		return GameColors.to_color(GameColors.WARNING)
	return GameColors.to_color(GameColors.DANGER)


#region 测试接口（TestAPI 调用）
# start_map_battle() / stop_battle() 本身是公开接口，TestAPI 直接调用。


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
			"map_id": "",
			"map_finished": false,
			"map": {},
			"map_kills": {},
			"pending_spawns": 0,
		}
	return _session.get_state()


## 测试：战斗窗口右上角的 FPS 文本
func get_fps_text_for_test() -> String:
	return fps_label.text

#endregion
