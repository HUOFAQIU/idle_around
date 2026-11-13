class_name TooltipWindow
extends PanelContainer

static var instance : TooltipWindow

## 提示框跟鼠标隔开多少像素
const GAP : float = 10.0

## 标题行（魂灵名 / 物品名 / 战斗坐标）和正文的字号
const TITLE_FONT_SIZE : int = 24
const BODY_FONT_SIZE : int = 16

## 容器名集中定义；用 preload 而不是全局类名，保证 --script 无头模式也能解析
const CONTAINER_IDS: GDScript = preload("res://Scripts/container_ids.gd")

## tooltip 层级：数值越大越优先，低层级不能覆盖仍然有效的高层级
enum Layer { COORD, ITEM }

## 本帧结算出来的显隐目标。
## 信号的收发发生在输入阶段、_process 在其后，所以一帧内的 hide + show
## 会被合并成「保持显示」；现在是窗口内浮层，不再有 OS 窗口撤建，但保留
## 这套结算可以继续合并同帧的 owner 切换。
var _want_visible : bool = false
## 本帧收到过隐藏请求
var _hide_armed : bool = false
## 当前占用 tooltip 的对象；真正隐藏时清空
var _owner : Object
## 当前层级，默认是战斗坐标
var _layer : int = Layer.COORD
## 标题行：魂灵名 / 物品名 / 战斗坐标
@onready var _title_label : Label = $Margin/VBox/TitleLabel
## 正文：魂灵 tooltip；非魂灵物品和战斗坐标没有正文
@onready var _body_label : RichTextLabel = $Margin/VBox/BodyLabel


func _ready() -> void:
	instance = self
	visible = false
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_body_label.add_theme_font_size_override("normal_font_size", BODY_FONT_SIZE)
	_body_label.visible = false
	_apply_panel_colors()
	reset_size()
	# 仓库、角色魂器网格、魂器窗口共用同一套悬停提示，避免每个窗口各写一份
	GBIS.sig_item_focused.connect(_on_item_focused)
	GBIS.sig_item_focus_lost.connect(_on_item_focus_lost)


func _process(_delta: float) -> void:
	if _hide_armed:
		_hide_armed = false
		_want_visible = false
		_owner = null
	# 先摆位再显示，免得在上一帧的位置上闪一下
	if _want_visible:
		_place_tip()
	if visible != _want_visible:
		visible = _want_visible


## 显示提示框；低层级不能覆盖仍然有效的高层级 owner。
## 本帧内收到的隐藏请求作废。body_text 支持 BBCode，为空时只显示标题行。
func show_tip(owner: Object, layer: int, title_name: String, body_text: String = "") -> void:
	if is_instance_valid(_owner) and _owner != owner and layer < _layer and not _hide_armed:
		return
	_owner = owner
	_layer = layer
	_set_text(title_name, body_text)
	_hide_armed = false
	_want_visible = true


## 收起来；只有当前 owner 能收，避免战斗窗口把物品提示关掉。
## 延迟到本帧末结算，期间又被 show 的话就不闪。
func hide_tip(owner: Object) -> void:
	if is_instance_valid(_owner) and _owner != owner:
		return
	_hide_armed = true


## 标题和正文只在文字真的变了才写；正文为空时隐藏正文标签，
## 让非魂灵物品 / 战斗坐标保持单行提示。尺寸跟着内容走。
func _set_text(title_text: String, body_text: String) -> void:
	var changed := false
	if _title_label.text != title_text:
		_title_label.text = title_text
		changed = true
	if _body_label.text != body_text:
		_body_label.text = body_text
		_body_label.visible = not body_text.is_empty()
		changed = true
	if changed:
		reset_size()


## 物品焦点：魂灵和魂器有正文，其他物品保持单行标题
func _on_item_focused(item_data: ItemData, container_name: String) -> void:
	var body := ""
	if item_data is SoulData:
		var soul := item_data as SoulData
		body = SoulTooltip.build(soul, true, _soul_preview(soul, container_name))
	elif item_data is SoulVesselData:
		body = VesselTooltip.build(item_data as SoulVesselData, true)
	show_tip(self, Layer.ITEM, item_data.item_name, body)


## 魂器窗口内的 COMBAT 魂灵带当前装备预览；魂器外的物品、见闻保持基础值。
## 战斗中且魂器已装备时用运行期值，否则按“装上这份魂器后”静态预览。
func _soul_preview(soul: SoulData, container_name: String) -> SoulDamagePreview:
	var vessel_window := SoulVesselWindow.instance
	if vessel_window == null or vessel_window.contents_container_name() != container_name:
		return null
	var vessel := vessel_window.contents_vessel()
	if vessel == null or vessel.vessel_kind != "COMBAT":
		return null
	var runtime := SoulRuntimeDB.get_runtime(soul)
	if runtime != null:
		return SoulDamagePreview.for_soul(soul, runtime)
	var grid := ContainerRepository.instance.get_container(CONTAINER_IDS.VESSEL_GRID)
	return SoulDamagePreview.preview_for(soul, vessel, SoulVesselData.combat_souls_in(grid))


func _on_item_focus_lost(_item_data: ItemData) -> void:
	hide_tip(self)


## 自己决定往哪边弹：锚点是主视口内的鼠标，边界是主视口
func _place_tip() -> void:
	_place_near(get_viewport().get_mouse_position(), get_viewport_rect().size)


## 面板颜色统一从 GameColors 取；场景里只留边框宽度和圆角
func _apply_panel_colors() -> void:
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style == null:
		return
	style.bg_color = GameColors.to_color(GameColors.TOOLTIP_BG)
	style.border_color = GameColors.to_color(GameColors.TOOLTIP_BORDER)
	add_theme_stylebox_override("panel", style)


## 摆位：默认在鼠标右下方，右边放不下就翻到左边，翻过头再夹回视口里。
func _place_near(anchor: Vector2, bounds: Vector2) -> void:
	var tip := size

	var pos := anchor + Vector2(GAP, GAP)
	if pos.x + tip.x > bounds.x:
		pos.x = anchor.x - GAP - tip.x
	if pos.y + tip.y > bounds.y:
		pos.y = anchor.y - GAP - tip.y

	pos.x = clampf(pos.x, 0.0, maxf(0.0, bounds.x - tip.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, bounds.y - tip.y))
	# 鼠标停着不动时不要每帧重排浮层。
	if not position.is_equal_approx(pos):
		position = pos
