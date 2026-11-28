class_name TooltipService
extends RefCounted

enum Layer { COORD, ITEM }

static var _host: Control = null
static var _show_fn: Callable = Callable()
static var _hide_fn: Callable = Callable()


static func bind(host: Control, show_fn: Callable, hide_fn: Callable) -> void:
	_host = host
	_show_fn = show_fn
	_hide_fn = hide_fn


static func unbind(host: Control) -> void:
	if _host != host:
		return
	_host = null
	_show_fn = Callable()
	_hide_fn = Callable()


static func get_host() -> Control:
	return _host if is_instance_valid(_host) else null


static func show_tip(
	tip_owner: Object,
	layer: int,
	title_name: String,
	body_text: String = ""
) -> void:
	if is_instance_valid(_host) and _show_fn.is_valid():
		_show_fn.call(tip_owner, layer, title_name, body_text)


static func hide_tip(tip_owner: Object) -> void:
	if is_instance_valid(_host) and _hide_fn.is_valid():
		_hide_fn.call(tip_owner)
