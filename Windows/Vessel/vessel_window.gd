class_name SoulVesselWindow
extends BaseWindow

const WINDOW_PADDING : int = 16

static var instance : SoulVesselWindow

@onready var inventory_view: InventoryView = $VBox/Contents

var _vessel: SoulVesselData
var _contents_name: String = ""


func _ready() -> void:
	super()
	instance = self
	title = "魂器"
	GBIS.sig_item_activated.connect(_on_item_activated)
	GBIS.sig_inv_item_removed.connect(_on_item_removed)
	visibility_changed.connect(_on_visibility_changed)


func open_for(vessel: SoulVesselData) -> void:
	if vessel == null:
		return
	if _vessel == vessel and visible:
		inventory_view.mark_dirty()
		return
	_vessel = vessel
	var contents := vessel.ensure_contents()
	_contents_name = contents.container_name
	ContainerRepository.instance.register_container_data(contents.container_name, contents)
	if not GBIS.inventory_names.has(contents.container_name):
		GBIS.inventory_names.append(contents.container_name)
	title = vessel.item_name
	inventory_view.change_data_source(contents.container_name)
	inventory_view.mark_dirty()
	if not visible:
		open_window()
	_fit_to_contents(contents)
	if not GBIS.opened_containers.has(contents.container_name):
		GBIS.opened_containers.append(contents.container_name)


func contents_container_name() -> String:
	return _contents_name


func contents_vessel() -> SoulVesselData:
	return _vessel


func _on_visibility_changed() -> void:
	if visible or _vessel == null:
		return
	var container_name := _vessel.ensure_contents().container_name
	GBIS.opened_containers.erase(container_name)
	if GBIS.moving_item_service.is_dragging():
		return
	GBIS.inventory_names.erase(container_name)
	ContainerRepository.instance.remove_container(container_name)


func _on_item_removed(_inv_name: String, item_data: ItemData) -> void:
	if item_data != _vessel:
		return
	hide()
	_vessel = null
	_contents_name = ""


func _on_item_activated(item_data: ItemData) -> void:
	if item_data is SoulVesselData:
		open_for(item_data as SoulVesselData)


func _fit_to_contents(contents: ContainerData) -> void:
	var bounds := Vector2i(get_parent().get_viewport().get_visible_rect().size)
	var want := Vector2i(
		contents.columns * inventory_view.base_size + WINDOW_PADDING,
		contents.rows * inventory_view.base_size + TITLE_BAR_HEIGHT + WINDOW_PADDING
	)
	size = Vector2(
		clampi(want.x, 1, bounds.x),
		clampi(want.y, 1, bounds.y)
	)
	position = _clamp_position(position)
