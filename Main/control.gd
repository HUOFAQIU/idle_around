extends Control

@onready var button: Button = $PetPanel/GridContainer/Button
@onready var button_3: Button = $PetPanel/GridContainer/Button3
@onready var button_4: Button = $PetPanel/GridContainer/Button4
@onready var button_5: Button = $PetPanel/GridContainer/Button5
@onready var button_6: Button = $PetPanel/GridContainer/Button6
@onready var button_7: Button = $PetPanel/GridContainer/Button7
@onready var button_8: Button = $PetPanel/GridContainer/Button8
@onready var button_9: Button = $PetPanel/GridContainer/Button9

@onready var character_window: CharacterWindow = $CharacterWindow
@onready var inventory_window: InventoryWindow = $InventoryWindow
@onready var battle_window: BattleWindow = $BattleWindow
@onready var shop_window: BaseWindow = $ShopWindow
@onready var collection_window: CollectionWindow = $CollectionWindow
@onready var debug_window: DebugWindow = $DebugWindow
@onready var mod_window: ModWindow = $ModWindow
@onready var panel_manager: PanelManager = $PanelManager


func _ready() -> void:
	button.pressed.connect(
		func ():
			popup_window(character_window)
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


func popup_window(window: BaseWindow) -> void:
	panel_manager.toggle(window)
