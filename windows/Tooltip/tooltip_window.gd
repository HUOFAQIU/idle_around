class_name TooltipWindow
extends PanelContainer

static var instance : TooltipWindow

const GAP : float = 10.0

const BODY_FONT_SIZE : int = 16
const TITLE_SPAN_ROWS : int = 2

const CONTAINER_IDS: GDScript = preload("res://scripts/container_ids.gd")

enum Layer { COORD, ITEM }

var _want_visible : bool = false
var _hide_armed : bool = false
var _owner : Object
var _layer : int = Layer.COORD
var _title_text : String = ""
var _body_text : String = ""
@onready var _body_terminal : TerminalView = $Margin/VBox/BodyTerminal


func _ready() -> void:
	instance = self
	visible = false
	_body_terminal.font_size = BODY_FONT_SIZE
	_body_terminal.visible = false
	_apply_panel_colors()
	reset_size()
	GBIS.sig_item_focused.connect(_on_item_focused)
	GBIS.sig_item_focus_lost.connect(_on_item_focus_lost)


func _process(_delta: float) -> void:
	if _hide_armed:
		_hide_armed = false
		_want_visible = false
		_owner = null
	if _want_visible:
		_place_tip()
	if visible != _want_visible:
		visible = _want_visible


func show_tip(tip_owner: Object, layer: int, title_name: String, body_text: String = "") -> void:
	if is_instance_valid(_owner) and _owner != tip_owner and layer < _layer and not _hide_armed:
		return
	_owner = tip_owner
	_layer = layer
	_set_text(title_name, body_text)
	_hide_armed = false
	_want_visible = true


func hide_tip(tip_owner: Object) -> void:
	if is_instance_valid(_owner) and _owner != tip_owner:
		return
	_hide_armed = true


func _set_text(title_text: String, body_text: String) -> void:
	if _title_text == title_text and _body_text == body_text:
		return
	_title_text = title_text
	_body_text = body_text
	_body_terminal.visible = not title_text.is_empty() or not body_text.is_empty()
	if not _body_terminal.visible:
		reset_size()
		return
	var title_span: TerminalSpan = null
	var title_size := Vector2i.ZERO
	if not title_text.is_empty():
		title_size = _body_terminal.measure_span(title_text, TITLE_SPAN_ROWS)
		title_span = TerminalSpan.new()
		title_span.text = title_text
		title_span.rows = TITLE_SPAN_ROWS
		var title_style := TerminalStyle.new()
		title_style.underline = true
		title_span.style = title_style
	var body_top := title_size.y
	_body_terminal.fit_text(body_text, body_top, maxi(title_size.x, 1))
	if not body_text.is_empty():
		_body_terminal.set_ansi_content(
			PackedStringArray([TooltipText.to_ansi(body_text)]), body_top
		)
	if title_span != null:
		var spans: Array[TerminalSpan] = []
		spans.append(title_span)
		_body_terminal.set_spans(spans)
	reset_size()


func _on_item_focused(item_data: ItemData, container_name: String) -> void:
	var body := ""
	if item_data is SoulData:
		var soul := item_data as SoulData
		body = SoulTooltip.build(
			soul, TooltipText.Format.PLAIN, _soul_preview(soul, container_name)
		)
	elif item_data is SoulVesselData:
		body = VesselTooltip.build(item_data as SoulVesselData, TooltipText.Format.PLAIN)
	elif item_data is MapItemData:
		body = MapTooltip.build(item_data as MapItemData, TooltipText.Format.PLAIN)
	elif item_data is QuantityStoneData:
		body = QuantityStoneTooltip.build(
			item_data as QuantityStoneData, TooltipText.Format.PLAIN
		)
	show_tip(self, Layer.ITEM, item_data.tooltip_title(), body)


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


func _place_tip() -> void:
	_place_near(get_viewport().get_mouse_position(), get_viewport_rect().size)


func _apply_panel_colors() -> void:
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style == null:
		return
	style.bg_color = GameColors.to_color(GameColors.TOOLTIP_BG)
	style.border_color = GameColors.to_color(GameColors.TOOLTIP_BORDER)
	add_theme_stylebox_override("panel", style)


func _place_near(anchor: Vector2, bounds: Vector2) -> void:
	var tip := size

	var pos := anchor + Vector2(GAP, GAP)
	if pos.x + tip.x > bounds.x:
		pos.x = anchor.x - GAP - tip.x
	if pos.y + tip.y > bounds.y:
		pos.y = anchor.y - GAP - tip.y

	pos.x = clampf(pos.x, 0.0, maxf(0.0, bounds.x - tip.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, bounds.y - tip.y))
	if not position.is_equal_approx(pos):
		position = pos
