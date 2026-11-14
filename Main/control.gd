class_name GameUI
extends Control
## 游戏 UI 根节点：窗口开关与主菜单请求解析。
##
## 主菜单 PetPanel 挂在立方体面 02 上，按钮请求由 Main/Cube 装配脚本
## 转进 open_panel()；窗口本身仍在主视口里，和以前一样弹出/置顶。

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


## 主菜单按钮请求：按 id 打开/关闭对应窗口
func open_panel(panel_id: StringName) -> void:
	popup_window(_panels.get(panel_id) as BaseWindow)


func popup_window(window: BaseWindow) -> void:
	panel_manager.toggle(window)
