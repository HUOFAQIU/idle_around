extends Node
## 物品焦点业务类
class_name ItemFocusService

## 当前焦点目标
var current_item_data: ItemData
var current_container_name: String = ""

## 有待结算的「焦点丢失」
var _lost_pending: bool = false

## 焦点物品
func focus_item(item_data: ItemData, container_name: String) -> void:
	# 如果当前有移动物品，则不允许焦点切换
	if GBIS.moving_item_service.is_dragging():
		return

	# 如果焦点没有变化，直接返回
	if current_item_data == item_data and current_container_name == container_name:
		# 又回到同一颗物品身上了，把待发的丢失撤掉
		_lost_pending = false
		return

	# 设置新焦点（换成别的物品，旧的丢失请求一并作废）
	_lost_pending = false
	current_item_data = item_data
	current_container_name = container_name
	GBIS.sig_item_focused.emit(item_data, current_container_name)

## 焦点丢失
## 一颗物品占好几个格子，鼠标在它内部跨格子时会「先离格、再进格」，
## 中间那一拍丢失不该真发出去，所以先记账、等本帧末再结算：
## 期间焦点又落回同一颗物品就把账销掉，真走了才发信号。
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

## 窗口关闭时手动调用，防止关闭后提示信息一直存在
func lost_by_container_close(container_name: String) -> void:
	if current_container_name != container_name:
		return
	item_lose_focus()
