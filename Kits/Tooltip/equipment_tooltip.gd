class_name EquipmentTooltip
extends TooltipBase

@onready var name_label: Label = $BG/VBoxContainer/NameLabel


func _ready() -> void:
	super()
	GBIS.sig_item_focused.connect(
		func (item_data: ItemData, container_name: String):
			print(item_data)
			name_label.text = item_data.item_name
			visible = true
			place_tip()
	)
	GBIS.sig_item_focus_lost.connect(
		func (item_data: ItemData):
			hide_tip()
	)
