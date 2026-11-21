@tool
extends Control
class_name DropAreaView

func _ready() -> void:
	if not Engine.is_editor_hint():
		GBIS.moving_item_service.register_drop_area(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	call_deferred("resize")
	hide()

func resize() -> void:
	if is_inside_tree():
		size = get_tree().root.size
		get_parent().move_child(self, 0)

func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(GBIS.input_click):
		GBIS.moving_item_service.drop_to_world()
