extends Control

@onready var button: Button = $GridContainer/Button
@onready var button_2: Button = $GridContainer/Button2
@onready var button_3: Button = $GridContainer/Button3
@onready var button_4: Button = $GridContainer/Button4
@onready var button_5: Button = $GridContainer/Button5
@onready var button_6: Button = $GridContainer/Button6
@onready var button_7: Button = $GridContainer/Button7
@onready var button_8: Button = $GridContainer/Button8
@onready var button_9: Button = $GridContainer/Button9

@onready var character_window: CharacterWindow = $CharacterWindow
@onready var equipment_window: Window = $EquipmentWindow
@onready var inventory_window: Window = $InventoryWindow
@onready var battle_window: BattleWindow = $BattleWindow
@onready var shop_window: BaseWindow = $ShopWindow
@onready var collection_window: Window = $CollectionWindow
@onready var debug_window: Window = $DebugWindow
@onready var mod_window: Window = $ModWindow


func _ready() -> void:
	button.pressed.connect(
		func ():
			popup_window(character_window)
	)
	button_2.pressed.connect(
		func ():
			popup_window(equipment_window)
	)
	button_3.pressed.connect(
		func ():
			popup_window(inventory_window)
	)
	button_4.pressed.connect(
		func ():
			popup_window(shop_window)
	)
	button_5.pressed.connect(
		func ():
			popup_window(battle_window)
	)
	button_6.pressed.connect(
		func ():
			popup_window(collection_window)
	)
	button_7.pressed.connect(
		func ():
			popup_window(debug_window)
	)
	button_9.pressed.connect(
		func ():
			popup_window(mod_window)
	)


func popup_window(window : Window) -> void:
	if window.visible:
		window.hide()
		return
	# BaseWindow 可以自带打开位置（open_position），没写就居中开
	if window is BaseWindow:
		(window as BaseWindow).open_window()
	else:
		window.popup_centered()
