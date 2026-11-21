extends Control
class_name BaseGridView

enum State{
	EMPTY, TAKEN, CONFLICT, AVILABLE
}

var state: State = State.EMPTY:
	set(value):
		state = value
		queue_redraw()

var grid_id: Vector2i = Vector2i.ZERO
var offset: Vector2i = Vector2i.ZERO
var has_taken: bool = false

var _size: int = 32
var _border_size: int = 1
var _border_color: Color = GameColors.to_color(GameColors.GRID_BORDER)
var _empty_color: Color = GameColors.to_color(GameColors.GRID_EMPTY)
var _taken_color: Color = GameColors.to_color(GameColors.GRID_TAKEN)
var _conflict_color: Color = GameColors.to_color(GameColors.GRID_CONFLICT)
var _avilable_color: Color = GameColors.to_color(GameColors.GRID_AVAILABLE)

var _container_view: BaseContainerView

func taken(in_offset: Vector2i) -> void:
	has_taken = true
	offset = in_offset
	state = State.TAKEN

func release() -> void:
	has_taken = false
	self.offset = Vector2i.ZERO
	state = State.EMPTY

func _init(inventoryView: BaseContainerView, in_grid_id: Vector2i, in_size: int, border_size: int,
	border_color: Color, empty_color: Color, taken_color: Color, conflict_color: Color, avilable_color: Color):
		_avilable_color = avilable_color
		_container_view = inventoryView
		grid_id = in_grid_id
		_size = in_size
		_border_size = border_size
		_border_color = border_color
		_empty_color = empty_color
		_taken_color = taken_color
		_conflict_color = conflict_color
		custom_minimum_size = Vector2(_size, _size)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_container_view.grid_hover.bind(grid_id))
	mouse_exited.connect(_container_view.grid_lose_hover.bind(grid_id))

func _draw() -> void:
	draw_rect(Rect2(0, 0, _size, _size), _border_color, true)
	var inner_size = _size - _border_size * 2
	var background_color = null
	match state:
		State.EMPTY:
			background_color = _empty_color
		State.TAKEN:
			background_color = _taken_color
		State.CONFLICT:
			background_color = _conflict_color
		State.AVILABLE:
			background_color = _avilable_color
	draw_rect(Rect2(_border_size, _border_size, inner_size, inner_size), background_color, true)
