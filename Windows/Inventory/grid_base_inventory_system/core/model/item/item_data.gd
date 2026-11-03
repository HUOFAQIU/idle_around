extends Resource
## 物品数据基类，不要直接继承这个类
class_name ItemData

## 调用后，将调用包含这个 data 的 view 的 queue_redraw()
## 场景：比如，强化装备后，修改了 shader 参数，但是不想重绘整个 Inventory，可以 emit 这个信号
signal sig_refresh

@export_group("Common Settings")
## 物品名称，需要唯一
@export var item_name: String = "Item Name"
## 物品大类，值为“ANY”表示所有大类
@export_enum("ANY", "SOUL") var category: String = "ANY"
@export_group("Display Settings")
## 物品图标
@export var icon: Texture2D
## 物品占的列数
@export var columns: int = 1
## 物品占的行数
@export var rows: int = 1
## view 上的材质，如果为空，则尝试获取 GBIS.material
@export var material: ShaderMaterial
## 把 shader 需要修改的参数设置在这里
@export var shader_params: Dictionary[String, Variant]

## 获取货品形状
func get_shape() -> Vector2i:
	return Vector2i(columns, rows)

## 改一个 shader 参数的值，并让用到它的 view 重绘
## （sig_refresh 就是为这种情况留的：只重画这一件，不用刷新整个背包）
func set_shader_param(param: String, value: Variant) -> void:
	# Godot 4 里 Dictionary 是引用类型，duplicate() 出来的物品跟原件共用同一个
	# shader_params —— 不先复制一份，改一颗会连带改掉所有同类实例，连预制资源本身也跑不掉
	shader_params = shader_params.duplicate()
	shader_params[param] = value
	sig_refresh.emit()

## 扫描线开关。只对材质挂 soul_scanline.gdshader 的物品有效；
## 挂在别的 shader 上也调不坏，只是多一个用不上的参数
func set_scanline_enabled(on: bool) -> void:
	set_shader_param("enable", 1.0 if on else 0.0)

## 扫描线当前开着没
func is_scanline_enabled() -> bool:
	return float(shader_params.get("enable", 1.0)) > 0.5

func can_drop() -> bool:
	push_warning("[Override this function] check if the item [%s] can drop" % item_name)
	return true

## 丢弃物品时调用，需重写
func drop() -> void:
	push_warning("[Override this function] item [%s] dropped" % item_name)

## 物品是否能出售（是否贵重物品等）
func can_sell() -> bool:
	push_warning("[Override this function] check if the item [%s] can be sell" % item_name)
	return true

## 物品是否能购买（检查资源是否足够等）
func can_buy() -> bool:
	push_warning("[Override this function] check if the item [%s] can be bought" % item_name)
	return true

## 购买后扣除资源
func cost() -> void:
	push_warning("[Override this function] [%s] cost resource" % item_name)

## 出售后增加资源
func sold() -> void:
	push_warning("[Override this function] [%s] add resource" % item_name)

## 购买并添加到背包
func buy() -> bool:
	if not can_buy():
		return false
	for target_inv in GBIS.inventory_names:
		if GBIS.inventory_service.add_item(target_inv, self):
			cost()
			return true
	return false
