class_name CoordTooltip
extends TooltipBase

@onready var name_label: Label = $BG/VBoxContainer/NameLabel
@onready var info_label: Label = $BG/VBoxContainer/InfoLabel


func _ready() -> void:
	super()
