extends BaseWindow

@export var items: Array[ItemData]

@onready var button: Button = $GridContainer/Button
@onready var button_2: Button = $GridContainer/Button2
@onready var button_3: Button = $GridContainer/Button3
@onready var button_4: Button = $GridContainer/Button4
@onready var button_5: Button = $GridContainer/Button5
@onready var button_6: Button = $GridContainer/Button6


func _ready() -> void:
	super()
	title = "仓库窗口"
	
	button.pressed.connect(button_pressed)
	button_4.pressed.connect(button_4_pressed)
	button_5.pressed.connect(button_5_pressed)
	button_6.pressed.connect(button_6_pressed)


func button_pressed() -> void:
	GBIS.add_item("inventory_0", preload("uid://c7o1ldy56mwu6"))

func button_4_pressed() -> void:
	GBIS.add_item("inventory_0", preload("uid://c7o1ldy56mwu6"))

func button_5_pressed() -> void:
	GBIS.add_item("inventory_0", preload("uid://c7o1ldy56mwu6"))

func button_6_pressed() -> void:
	GBIS.add_item("inventory_0", preload("uid://c7o1ldy56mwu6"))
