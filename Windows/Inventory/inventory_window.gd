extends BaseWindow

@onready var button: Button = $GridContainer/Button
@onready var button_2: Button = $GridContainer/Button2
@onready var button_3: Button = $GridContainer/Button3

## 调试用：往仓库里塞一颗魂灵。
## 带 skill 的魂灵拖进魂灵窗口的格子，战斗里角色才会放技能；
## 盾是早期的样例魂灵（没挂技能），留着占位
const XIAO_LU = preload("res://game/content/Player/xiao_lu.tres")
const DUN = preload("res://game/content/Player/medium_0001.tres")
const CHANG_GONG = preload("res://game/content/Player/chang_gong.tres")


func _ready() -> void:
	super()
	title = "仓库窗口"
	
	button.pressed.connect(button_pressed)
	button_2.pressed.connect(button_2_pressed)
	button_3.pressed.connect(button_3_pressed)
	
	GBIS.sig_item_focused.connect(
		func (item_data: ItemData, container_name: String):
			TooltipWindow.instance.show_tip()
			TooltipWindow.instance.set_window_title(item_data.item_name)
	)
	GBIS.sig_item_focus_lost.connect(
		func (item_data: ItemData):
			TooltipWindow.instance.hide_tip()
	)


func button_pressed() -> void:
	GBIS.add_item("inventory_0", XIAO_LU)

func button_2_pressed() -> void:
	GBIS.add_item("inventory_0", DUN)

func button_3_pressed() -> void:
	GBIS.add_item("inventory_0", CHANG_GONG)
