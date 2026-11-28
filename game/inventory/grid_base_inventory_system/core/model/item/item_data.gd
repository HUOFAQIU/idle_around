extends Resource
class_name ItemData

signal sig_refresh

## 运行期稳定 ID：由 ModLoader 从 manifest 写入（core 沿用原 ID）。
## 由 ModLoader 写入；不要在资源里手填，也不要拿来显示。
@export_storage var content_id: StringName = &""

@export_group("Common Settings")
## 物品显示名；只用于 UI/日志，不参与 ID、存档查找或唯一性约束
@export var item_name: String = "Item Name"
## 物品大类，值为“ANY”表示所有大类
@export_enum("ANY", "SOUL", "VESSEL", "MAP", "STONE") var category: String = "ANY"
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

func get_shape() -> Vector2i:
	return Vector2i(columns, rows)


func tooltip_title() -> String:
	return item_name


func make_instance() -> ItemData:
	return duplicate() as ItemData


func activate() -> bool:
	return false


func container_kind_tag() -> String:
	return ""

func set_shader_param(param: String, value: Variant) -> void:
	shader_params = shader_params.duplicate()
	shader_params[param] = value
	sig_refresh.emit()

func set_scanline_enabled(on: bool) -> void:
	set_shader_param("enable", 1.0 if on else 0.0)

func is_scanline_enabled() -> bool:
	return float(shader_params.get("enable", 1.0)) > 0.5

func can_drop() -> bool:
	push_warning("[Override this function] check if the item [%s] can drop" % item_name)
	return true

func drop() -> void:
	push_warning("[Override this function] item [%s] dropped" % item_name)

func can_sell() -> bool:
	push_warning("[Override this function] check if the item [%s] can be sell" % item_name)
	return true

func can_buy() -> bool:
	push_warning("[Override this function] check if the item [%s] can be bought" % item_name)
	return true

func cost() -> void:
	push_warning("[Override this function] [%s] cost resource" % item_name)

func sold() -> void:
	push_warning("[Override this function] [%s] add resource" % item_name)
