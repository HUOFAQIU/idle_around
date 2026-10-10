class_name CoordTooltip
extends TooltipBase

@onready var name_label: Label = $BG/VBoxContainer/NameLabel
@onready var info_label: Label = $BG/VBoxContainer/InfoLabel


func _ready() -> void:
	super()
	#GBIS.sig_item_focused.connect(
		#func (item_data: ItemData, container_name: String):
			#name_label.text = item_data.item_name
			#visible = true
			#place_tip()
	#)
	#GBIS.sig_item_focus_lost.connect(
		#func (item_data: ItemData):
			#hide_tip()
	#)


func _process(_delta: float) -> void:
	if visible:
		place_tip()


## 自己决定往哪边弹：锚点是鼠标，边界是自己所在窗口的矩形
func place_tip() -> void:
	place_near(get_global_mouse_position(), get_viewport_rect().size)
