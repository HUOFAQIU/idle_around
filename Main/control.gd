class_name GameUI
extends Control

var _panels: Dictionary = {}

@onready var character_window: CharacterWindow = $CharacterWindow
@onready var inventory_window: InventoryWindow = $InventoryWindow
@onready var battle_window: BattleWindow = $BattleWindow
@onready var shop_window: BaseWindow = $ShopWindow
@onready var collection_window: CollectionWindow = $CollectionWindow
@onready var debug_window: DebugWindow = $DebugWindow
@onready var mod_window: ModWindow = $ModWindow
@onready var terminal_window: TerminalWindow = $TerminalWindow
@onready var panel_manager: PanelManager = $PanelManager


func _ready() -> void:
	_panels = {
		&"character": character_window,
		&"inventory": inventory_window,
		&"shop": shop_window,
		&"battle": battle_window,
		&"collection": collection_window,
		&"debug": debug_window,
		&"terminal": terminal_window,
		&"mod": mod_window,
	}


func open_panel(panel_id: StringName) -> void:
	popup_window(_panels.get(panel_id) as BaseWindow)


func popup_window(window: BaseWindow) -> void:
	panel_manager.toggle(window)


func close_all_panels() -> void:
	panel_manager.hide_all()
