class_name SoulVesselWindow
extends BaseWindow
## 魂器窗口：显示一个魂器的内部容器，支持把魂灵从仓库拖进/拖出。
##
## 单例复用：右键不同的魂器时重新绑定同一个窗口。
## 魂器内部容器平时不在 ContainerRepository 里，打开窗口时按实例容器名注册，
## 这样 InventoryView、拖拽服务和悬停提示都能按普通容器处理；存档不走容器清单，
## 魂器的内部魂灵随物品记录一起嵌套保存。

## 窗口内边距
const WINDOW_PADDING : int = 16

static var instance : SoulVesselWindow

@onready var inventory_view: InventoryView = $VBox/Contents

## 当前显示的魂器
var _vessel: SoulVesselData
## 当前显示的内部容器名；魂器被移走后清空
var _contents_name: String = ""


func _ready() -> void:
	super()
	instance = self
	title = "魂器"
	GBIS.sig_item_activated.connect(_on_item_activated)
	GBIS.sig_inv_item_removed.connect(_on_item_removed)
	visibility_changed.connect(_on_visibility_changed)


## 右键魂器时打开；已经在显示同一个魂器则只保证可见
func open_for(vessel: SoulVesselData) -> void:
	if vessel == null:
		return
	if _vessel == vessel and visible:
		# 同一个魂器再次右键：只补一次重绘
		inventory_view.mark_dirty()
		return
	_vessel = vessel
	var contents := vessel.ensure_contents()
	_contents_name = contents.container_name
	ContainerRepository.instance.register_container_data(contents.container_name, contents)
	# 关窗时从 inventory_names 注销过；重新打开要补回，InventoryService 才能查到容器
	if not GBIS.inventory_names.has(contents.container_name):
		GBIS.inventory_names.append(contents.container_name)
	title = vessel.item_name
	inventory_view.change_data_source(contents.container_name)
	inventory_view.mark_dirty()
	if not visible:
		open_window()
	# 首次打开时 open_window 会把置顶栏高度补进窗口；尺寸放在它之后算，避免多加一次
	_fit_to_contents(contents)
	if not GBIS.opened_containers.has(contents.container_name):
		GBIS.opened_containers.append(contents.container_name)


## 当前显示的内部容器名；Tooltip 用它判断魂灵是否位于魂器窗口
func contents_container_name() -> String:
	return _contents_name


## 当前显示的魂器；没有绑定时为 null
func contents_vessel() -> SoulVesselData:
	return _vessel


## 窗口关闭后把内部容器移出“已打开”列表并注销；内容仍留在魂器里。
## 拖拽中的物品还可能需要这个容器，等下次打开窗口时重新注册。
func _on_visibility_changed() -> void:
	if visible or _vessel == null:
		return
	var container_name := _vessel.ensure_contents().container_name
	GBIS.opened_containers.erase(container_name)
	if GBIS.moving_item_service.is_dragging():
		return
	GBIS.inventory_names.erase(container_name)
	ContainerRepository.instance.remove_container(container_name)


## 魂器被移出容器（拖走/卖掉/丢弃）后关闭窗口，避免继续编辑一个不在世界里的魂器
func _on_item_removed(_inv_name: String, item_data: ItemData) -> void:
	if item_data != _vessel:
		return
	hide()
	_vessel = null
	_contents_name = ""


## 物品激活信号：只有魂器需要开窗
func _on_item_activated(item_data: ItemData) -> void:
	if item_data is SoulVesselData:
		open_for(item_data as SoulVesselData)


## 窗口尺寸跟着内部容器走；标题栏高度由 BaseWindow 负责
func _fit_to_contents(contents: ContainerData) -> void:
	var bounds := Vector2i(get_parent().get_viewport().get_visible_rect().size)
	var want := Vector2i(
		contents.columns * inventory_view.base_size + WINDOW_PADDING,
		contents.rows * inventory_view.base_size + TITLE_BAR_HEIGHT + WINDOW_PADDING
	)
	size = Vector2i(
		clampi(want.x, 1, bounds.x),
		clampi(want.y, 1, bounds.y)
	)
	position = _clamp_position(position)
