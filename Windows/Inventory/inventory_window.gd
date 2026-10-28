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
@onready var button_10: Button = $GridContainer/Button10
@onready var button_11: Button = $GridContainer/Button11
@onready var button_12: Button = $GridContainer/Button12
@onready var button_13: Button = $GridContainer/Button13
@onready var button_14: Button = $GridContainer/Button14
@onready var button_15: Button = $GridContainer/Button15

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
const JIAN_SHEN_FANG = preload("res://game/content/Souls/jian_shen_fang/jian_shen_fang_soul.tres")
const DAO_HUO_SHU = preload("res://game/content/Souls/dao_huo_shu/dao_huo_shu_soul.tres")
const QIANG_LAI_SHI = preload("res://game/content/Souls/qiang_laishi/qiang_laishi_soul.tres")
const CHUI_JIAN = preload("res://game/content/Souls/chui_jian/chui_jian_soul.tres")
const YI_CHANG_HU_WAN = preload("res://game/content/Souls/yi_chang_hu_wan/yi_chang_hu_wan_soul.tres")
const MIAN_BAO = preload("res://game/content/Souls/mian_bao/mian_bao_soul.tres")


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
	button_10.pressed.connect(button_10_pressed)
	button_11.pressed.connect(button_11_pressed)
	button_12.pressed.connect(button_12_pressed)
	button_13.pressed.connect(button_13_pressed)
	button_14.pressed.connect(button_14_pressed)
	button_15.pressed.connect(button_15_pressed)

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

func button_10_pressed() -> void:
	GBIS.add_item("inventory_0", JIAN_SHEN_FANG)

func button_11_pressed() -> void:
	GBIS.add_item("inventory_0", DAO_HUO_SHU)

func button_12_pressed() -> void:
	GBIS.add_item("inventory_0", QIANG_LAI_SHI)

func button_13_pressed() -> void:
	GBIS.add_item("inventory_0", CHUI_JIAN)

func button_14_pressed() -> void:
	GBIS.add_item("inventory_0", YI_CHANG_HU_WAN)

func button_15_pressed() -> void:
	GBIS.add_item("inventory_0", MIAN_BAO)
