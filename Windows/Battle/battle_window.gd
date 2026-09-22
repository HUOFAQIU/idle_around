class_name BattleWindow
extends BaseWindow

const PLAYER_MAX_HP : int = 500
## 怪物贴到身边后，每 3 秒咬一口的伤害
const BITE_DAMAGE : int = 20

## 战斗心跳：每 3 秒一拍 —— 所有怪一起朝中心挪一格，然后刷一只新的
const TURN_INTERVAL : float = 3.0
## 「距离 10 以外」：比这个距离远的格子才刷怪
const SPAWN_MIN_DISTANCE : int = 10

## 每 2 秒朝最近的怪打一发
const FIRE_INTERVAL : float = 2.0
const PROJECTILE_DAMAGE : int = 30

## 死后多久复活
const REVIVE_DELAY : float = 3.0

## 格子上画距离数字（调试用）
const SHOW_DEBUG_DISTANCE : bool = false

## 开发用的加速倍率（右上角按钮切换）
const FAST_SPEED : float = 10.0

@onready var tile: Node2D = $Tile
@onready var ground_tilemaplayer: TileMapLayer = $Tile/GroundTileMapLayer
@onready var player_token: Sprite2D = $Tile/PlayerToken
@onready var monsters: Node2D = $Tile/Monsters
@onready var projectiles: Node2D = $Tile/Projectiles
@onready var damage_numbers: Node2D = $Tile/DamageNumbers

# 跟随鼠标的坐标小面板
var coord_panel: PanelContainer
var coord_label: Label

var hp_label: Label
var death_label: Label
var speed_button: Button

var _player_hp : int = PLAYER_MAX_HP
var _dead : bool = false
var _move_accum : float = 0.0
var _fire_accum : float = 0.0
var _revive_accum : float = 0.0
## 开发用的加速倍率，1.0 就是正常速度
var _speed : float = 1.0


func _ready() -> void:
	super()
	title = "战斗窗口"
	
	_build_coord_panel()
	_build_hud()
	_update_hud()
	visibility_changed.connect(_apply_time_scale)

	if SHOW_DEBUG_DISTANCE:
		for cell in ground_tilemaplayer.get_used_cells():
			var label: Label = Label.new()
			label.size = Vector2(10, 10)
			label.add_theme_font_size_override("font_size", 12)

			var center: Vector2 = ground_tilemaplayer.map_to_local(cell)
			# Label 自身坐标是左上角，偏移一半尺寸来居中
			label.position = center - label.size / 2.0

			var d : int = hex_distance(Vector2i(0, 0), cell)
			if d % 2 != 0:
				label.add_theme_color_override("font_color", Color.WHITE)
			else:
				label.add_theme_color_override("font_color", Color.BLACK)
			label.text = str(d)
			ground_tilemaplayer.add_child(label)


func _physics_process(delta: float) -> void:
	# 窗口没开着就整场暂停
	if not visible:
		return

	_update_coord_panel()
	_tick_battle(delta)


# ---------------------------------------------------------------- 战斗

func _tick_battle(delta: float) -> void:
	if _dead:
		_revive_accum += delta
		if _revive_accum >= REVIVE_DELAY:
			_revive()
		return

	_move_accum += delta
	if _move_accum >= TURN_INTERVAL:
		_move_accum -= TURN_INTERVAL
		_monster_turn()

	_fire_accum += delta
	if _fire_accum >= FIRE_INTERVAL:
		_fire_accum -= FIRE_INTERVAL
		_fire()


# 3 秒一拍：所有怪朝中心挪一格，已经贴到玩家的就咬一口，然后刷一只新的
# 一格只站一只怪：前面有怪挡着，这一拍就原地等着（排成一队往里走）
func _monster_turn() -> void:
	var occupied := _occupied_cells()
	var bites : int = 0

	for node in monsters.get_children():
		if node.is_queued_for_deletion():
			continue
		var monster := node as Monster
		if monster == null:
			continue

		var next := _next_cell_toward_center(monster.cell)
		if next == monster.cell:
			# 贴到玩家了，咬一口
			bites += 1
		elif not occupied.has(next):
			occupied.erase(monster.cell)
			occupied[next] = true
			monster.step_to(next, ground_tilemaplayer.map_to_local(next))

	if bites > 0:
		_hurt_player(bites * BITE_DAMAGE)
	if not _dead:
		_spawn_monster()


# 现在被怪占着的格子
func _occupied_cells() -> Dictionary:
	var occupied := {}
	for node in monsters.get_children():
		if node.is_queued_for_deletion():
			continue
		var monster := node as Monster
		if monster:
			occupied[monster.cell] = true
	return occupied


# 朝中心走一格；已经贴到玩家（距离 1）就原地不动，等着咬
func _next_cell_toward_center(cell: Vector2i) -> Vector2i:
	var d := hex_distance(cell, Vector2i.ZERO)
	if d <= 1:
		return cell
	# 六个邻居里，朝中心走的那一格距离正好少 1
	for neighbor in ground_tilemaplayer.get_surrounding_cells(cell):
		if hex_distance(neighbor, Vector2i.ZERO) == d - 1:
			return neighbor
	return cell


func _spawn_monster() -> void:
	var candidates := _free_spawn_cells()
	if candidates.is_empty():
		return
	var cell : Vector2i = candidates.pick_random()
	var monster := Monster.new()
	monster.cell = cell
	monster.position = ground_tilemaplayer.map_to_local(cell)
	monsters.add_child(monster)


# 距离中心 10 以外、且没被别的怪占着的格子
# 注意：棋盘上格子坐标有负数，别拿负数当「没位置」的标记
func _free_spawn_cells() -> Array[Vector2i]:
	var taken := _occupied_cells()

	var cells : Array[Vector2i] = []
	for cell in ground_tilemaplayer.get_used_cells():
		if hex_distance(cell, Vector2i.ZERO) > SPAWN_MIN_DISTANCE and not taken.has(cell):
			cells.append(cell)
	return cells


func _fire() -> void:
	var target := _nearest_monster()
	if target == null:
		return

	var projectile := Projectile.new()
	projectile.position = player_token.position
	projectile.setup(target.position - player_token.position, monsters)
	projectile.hit.connect(_on_projectile_hit)
	projectiles.add_child(projectile)


func _nearest_monster() -> Monster:
	var nearest : Monster = null
	var nearest_distance : float = INF
	for node in monsters.get_children():
		if node.is_queued_for_deletion():
			continue
		var monster := node as Monster
		if monster == null:
			continue
		var d := player_token.position.distance_to(monster.position)
		if d < nearest_distance:
			nearest_distance = d
			nearest = monster
	return nearest


func _on_projectile_hit(monster: Monster) -> void:
	if monster.is_queued_for_deletion():
		return
	_pop_damage(monster.position, PROJECTILE_DAMAGE)
	if monster.take_damage(PROJECTILE_DAMAGE):
		monster.queue_free()


func _hurt_player(amount: int) -> void:
	if _dead:
		return
	_player_hp = maxi(_player_hp - amount, 0)
	_update_hud()
	if _player_hp <= 0:
		_die()


func _die() -> void:
	_dead = true
	_revive_accum = 0.0
	# 清场：怪、飞行物、跳着的数字全清掉
	for container in [monsters, projectiles, damage_numbers]:
		for child in container.get_children():
			child.queue_free()
	_update_hud()


func _revive() -> void:
	_dead = false
	_player_hp = PLAYER_MAX_HP
	_move_accum = 0.0
	_fire_accum = 0.0
	_update_hud()


# 怪物身上跳一个伤害数字
func _pop_damage(pos: Vector2, amount: int) -> void:
	var label := Label.new()
	label.text = str(amount)
	label.size = Vector2(40, 20)
	label.position = pos - Vector2(20, 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	damage_numbers.add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -24), 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)


# ---------------------------------------------------------------- 界面

func _build_hud() -> void:
	hp_label = Label.new()
	hp_label.position = Vector2(14, 10)
	hp_label.add_theme_font_size_override("font_size", 20)
	add_child(hp_label)

	# 开发用：切换 10 倍速
	speed_button = Button.new()
	speed_button.text = "1×"
	speed_button.toggle_mode = true
	speed_button.position = Vector2(14, 42)
	speed_button.custom_minimum_size = Vector2(64, 32)
	speed_button.tooltip_text = "开发用：10 倍速（窗口关掉就恢复）"
	speed_button.toggled.connect(_on_speed_toggled)
	add_child(speed_button)

	death_label = Label.new()
	death_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.add_theme_font_size_override("font_size", 72)
	death_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25))
	death_label.text = "角色死亡"
	death_label.visible = false
	add_child(death_label)


func _update_hud() -> void:
	hp_label.text = "HP %d / %d" % [_player_hp, PLAYER_MAX_HP]
	death_label.visible = _dead


func _on_speed_toggled(pressed: bool) -> void:
	_speed = FAST_SPEED if pressed else 1.0
	speed_button.text = "%d×" % int(_speed)
	_apply_time_scale()


# 加速走的是 Engine.time_scale，所以是「整个游戏一起快」，不只是这个窗口。
# 窗口关着的时候一定要还原成 1 倍，免得这个开发开关漏到游戏别的部分去。
func _apply_time_scale() -> void:
	Engine.time_scale = _speed if visible else 1.0


# 创建一个跟随鼠标的小面板，里面显示 hover 到的格子坐标
func _build_coord_panel() -> void:
	coord_panel = PanelContainer.new()
	coord_panel.z_index = 99
	coord_panel.size = Vector2(50, 50)
	coord_label = Label.new()
	coord_label.add_theme_font_size_override("font_size", 12)
	coord_panel.add_child(coord_label)

	# 与磁贴放在同一坐标系里，位置用局部坐标直接算
	ground_tilemaplayer.add_child(coord_panel)

	# 不拦截鼠标，避免影响对磁贴的操作
	coord_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coord_panel.visible = false


func _update_coord_panel() -> void:
	# 鼠标在 TileMapLayer 局部坐标系中的位置
	var local_mouse := ground_tilemaplayer.get_local_mouse_position()
	# 鼠标所指的格子
	var hovered_cell := ground_tilemaplayer.local_to_map(local_mouse)

	# 鼠标不在有效图块上 -> 隐藏面板
	if ground_tilemaplayer.get_cell_source_id(hovered_cell) == -1:
		coord_panel.visible = false
		return

	# 显示坐标，并把面板放到鼠标旁边，自动避开窗口四边
	coord_label.text = str(hex_distance(Vector2i(0, 0), hovered_cell))
	_place_coord_panel(local_mouse)
	coord_panel.visible = true


# 计算与中心点的距离
func hex_distance(a: Vector2i, b: Vector2i) -> int:
	# 把 Godot 的 offset 坐标转成 axial，再转 cube，取三个轴的最大差
	var a_cube := _offset_to_cube(a)
	var b_cube := _offset_to_cube(b)
	return max(absi(a_cube.x - b_cube.x), absi(a_cube.y - b_cube.y), absi(a_cube.z - b_cube.z))


func _offset_to_cube(coord: Vector2i) -> Vector3i:
	# pointy-top：偶数行偏移，q = col - (row - (row & 1)) / 2
	var q := coord.x - (coord.y - (coord.y & 1)) / 2
	var r := coord.y
	var s := -q - r
	return Vector3i(q, r, s)

# 把面板放到鼠标旁，根据鼠标靠近的窗口边缘自动翻转方向并 clamp 到可视区内
func _place_coord_panel(local_mouse: Vector2) -> void:
	var gap := 14.0
	var panel_size := coord_panel.get_combined_minimum_size()

	# 窗口可视区域换算到 TileMapLayer 局部坐标
	var view_rect := get_viewport().get_visible_rect()
	var vp_top_left := ground_tilemaplayer.to_local(view_rect.position)
	var vp_bottom_right := ground_tilemaplayer.to_local(view_rect.end)

	# 默认放在鼠标右下方
	var dir_x := 1.0
	var dir_y := 1.0

	# 右侧放不下 -> 翻到左侧
	if local_mouse.x + gap + panel_size.x > vp_bottom_right.x:
		dir_x = -1.0
	# 下方放不下 -> 翻到上方
	if local_mouse.y + gap + panel_size.y > vp_bottom_right.y:
		dir_y = -1.0

	var pos := local_mouse + Vector2(gap * dir_x, gap * dir_y)
	if dir_x < 0.0:
		pos.x -= panel_size.x
	if dir_y < 0.0:
		pos.y -= panel_size.y

	# 最终 clamp 到可视区域内，确保不越界
	var max_x := maxf(vp_top_left.x, vp_bottom_right.x - panel_size.x)
	var max_y := maxf(vp_top_left.y, vp_bottom_right.y - panel_size.y)
	pos.x = clampf(pos.x, vp_top_left.x, max_x)
	pos.y = clampf(pos.y, vp_top_left.y, max_y)
	coord_panel.position = pos
