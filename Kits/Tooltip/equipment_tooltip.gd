class_name EquipmentTooltip
extends TooltipBase

@onready var name_label: Label = $BG/VBoxContainer/NameLabel
@onready var tooltip_window: TooltipWindow = $"../../TooltipWindow"


func _ready() -> void:
	super()
	GBIS.sig_item_focused.connect(
		func (item_data: ItemData, container_name: String):
			visible = true
			tooltip_window.place_tip()
	)
	GBIS.sig_item_focus_lost.connect(
		func (item_data: ItemData):
			tooltip_window.hide_tip()
	)
