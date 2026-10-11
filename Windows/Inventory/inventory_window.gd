extends BaseWindow

@onready var button: Button = $GridContainer/Button
@onready var button_2: Button = $GridContainer/Button2
@onready var button_3: Button = $GridContainer/Button3

const SMALL_0001 = preload("uid://d4dvhctbc8pk2")
const MEDIUM_0001 = preload("uid://cooi7q46e2n0g")
const LARGE_0001 = preload("uid://dnbx5yjtetb2y")

@onready var tooltip_window: TooltipWindow = $"../TooltipWindow"


func _ready() -> void:
	super()
	title = "仓库窗口"
	
	button.pressed.connect(button_pressed)
	button_2.pressed.connect(button_2_pressed)
	button_3.pressed.connect(button_3_pressed)
	
	GBIS.sig_item_focused.connect(
		func (item_data: ItemData, container_name: String):
			tooltip_window.visible = true
			tooltip_window.place_tip()
	)
	GBIS.sig_item_focus_lost.connect(
		func (item_data: ItemData):
			tooltip_window.hide_tip()
	)


func button_pressed() -> void:
	GBIS.add_item("inventory_0", SMALL_0001)

func button_2_pressed() -> void:
	GBIS.add_item("inventory_0", MEDIUM_0001)

func button_3_pressed() -> void:
	GBIS.add_item("inventory_0", LARGE_0001)
