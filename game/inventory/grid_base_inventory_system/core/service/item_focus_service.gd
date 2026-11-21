extends Node
class_name ItemFocusService

var current_item_data: ItemData
var current_container_name: String = ""

var _lost_pending: bool = false

func focus_item(item_data: ItemData, container_name: String) -> void:
	if GBIS.moving_item_service.is_dragging():
		return

	if current_item_data == item_data and current_container_name == container_name:
		_lost_pending = false
		return

	_lost_pending = false
	current_item_data = item_data
	current_container_name = container_name
	GBIS.sig_item_focused.emit(item_data, current_container_name)

func item_lose_focus() -> void:
	if not current_item_data:
		return
	_lost_pending = true
	_flush_lost.call_deferred()

func _flush_lost() -> void:
	if not _lost_pending:
		return
	_lost_pending = false
	GBIS.sig_item_focus_lost.emit(current_item_data.duplicate())
	current_item_data = null
	current_container_name = ""

func lost_by_container_close(container_name: String) -> void:
	if current_container_name != container_name:
		return
	item_lose_focus()
