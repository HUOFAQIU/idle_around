extends BaseWindow

@onready var button: Button = $GridContainer/Button
@onready var button_2: Button = $GridContainer/Button2
@onready var button_3: Button = $GridContainer/Button3
@onready var button_4: Button = $GridContainer/Button4
@onready var button_5: Button = $GridContainer/Button5
@onready var button_6: Button = $GridContainer/Button6
@onready var button_7: Button = $GridContainer/Button7
@onready var button_8: Button = $GridContainer/Button8
@onready var button_9: Button = $GridContainer/Button9

## 调试用：往仓库里塞一颗魂灵。
## 带 skill 的魂灵拖进魂灵窗口的格子，战斗里角色才会放技能；
## 盾是早期的样例魂灵（没挂技能），留着占位
const XIAO_LU = preload("res://game/content/Souls/xiao_lu/xiao_lu_soul.tres")
const DUN = preload("res://game/content/Souls/dun/dun_soul.tres")
const CHANG_GONG = preload("res://game/content/Souls/chang_gong/chang_gong_soul.tres")
const SONG_SHU = preload("res://game/content/Souls/song_shu/song_shu_soul.tres")
const KA_FEI = preload("res://game/content/Souls/ka_fei/ka_fei_soul.tres")
const YU = preload("res://game/content/Souls/yu/yu_soul.tres")
const WA = preload("res://game/content/Souls/wa/wa_soul.tres")
const DIAN_CHI = preload("res://game/content/Souls/dian_chi/dian_chi_soul.tres")
const YAO_DAI = preload("res://game/content/Souls/yao_dai/yao_dai_soul.tres")


func _ready() -> void:
	super()
	title = "仓库窗口"
	
	button.pressed.connect(button_pressed)
	button_2.pressed.connect(button_2_pressed)
	button_3.pressed.connect(button_3_pressed)
	button_4.pressed.connect(button_4_pressed)
	button_5.pressed.connect(button_5_pressed)
	button_6.pressed.connect(button_6_pressed)
	button_7.pressed.connect(button_7_pressed)
	button_8.pressed.connect(button_8_pressed)
	button_9.pressed.connect(button_9_pressed)

	GBIS.sig_item_focused.connect(
		func (item_data: ItemData, container_name: String):
			TooltipWindow.instance.show_tip(self, TooltipWindow.Layer.ITEM, item_data.item_name)
	)
	GBIS.sig_item_focus_lost.connect(
		func (item_data: ItemData):
			TooltipWindow.instance.hide_tip(self)
	)


func button_pressed() -> void:
	GBIS.add_item("inventory_0", XIAO_LU)

func button_2_pressed() -> void:
	GBIS.add_item("inventory_0", DUN)

func button_3_pressed() -> void:
	GBIS.add_item("inventory_0", CHANG_GONG)

func button_4_pressed() -> void:
	GBIS.add_item("inventory_0", SONG_SHU)

func button_5_pressed() -> void:
	GBIS.add_item("inventory_0", KA_FEI)

func button_6_pressed() -> void:
	GBIS.add_item("inventory_0", YU)

func button_7_pressed() -> void:
	GBIS.add_item("inventory_0", WA)

func button_8_pressed() -> void:
	GBIS.add_item("inventory_0", DIAN_CHI)

func button_9_pressed() -> void:
	GBIS.add_item("inventory_0", YAO_DAI)
