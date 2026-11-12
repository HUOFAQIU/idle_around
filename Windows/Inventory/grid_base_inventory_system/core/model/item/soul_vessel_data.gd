extends ItemData
## 魂器：装魂灵的容器物品。
##
## 静态数据：物品占格（columns / rows）、内部容器尺寸、魂器类型、效果和 tooltip 文案。
## 运行时数据：contents 保存这个实例里的魂灵；模板资源不保存内容，
## 每次生成物品实例时由 make_instance() 建一份独立的 ContainerData。
##
## 内部容器只收 SOUL；容器名按实例 id 生成，打开魂器窗口时注册到
## ContainerRepository，供 InventoryView 和拖拽服务查找。它不属于存档里的固定容器。
class_name SoulVesselData

## 魂器类型；与 ContainerData.vessel_kind 的过滤值对应。
## COMBAT 可以装进角色魂器槽；TOOL 只能放在背包/仓库。
@export_enum("COMBAT", "TOOL") var vessel_kind: String = "COMBAT"
## 内部容器列数
@export var container_columns: int = 6
## 内部容器行数
@export var container_rows: int = 2
## tooltip 效果段落；分隔线由格式化器插入
@export var tooltip_blocks: Array[String] = []
## 对容器内魂灵生效的效果；当前只实现直接伤害加成
@export var effects: Array[SoulVesselEffect] = []

## 这个实例的内部容器；模板为 null，物品实例在 make_instance() 时创建
var contents: ContainerData


func make_instance() -> ItemData:
	var copy := duplicate() as SoulVesselData
	# 必须由复制体建容器：容器名用实例 id，若在源对象上建，同一模板的
	# 所有副本会拿到同一个容器名，战斗里跨魂器串位。
	copy.contents = copy._clone_contents_from(contents)
	return copy


## 右键激活：由 UI 层监听 sig_item_activated 后打开魂器窗口
func activate() -> bool:
	return true


## 容器过滤用类型标签
func container_kind_tag() -> String:
	return vessel_kind


## 确保内部容器存在；模板被直接使用时兜底
func ensure_contents() -> ContainerData:
	if contents == null:
		contents = _new_contents()
	return contents


## 对容器内魂灵的直接伤害加成合计
func soul_damage_bonus() -> float:
	var bonus := 0.0
	for effect in effects:
		if effect != null and effect.stat == SoulVesselEffect.Stat.DAMAGE_BONUS:
			bonus += effect.value
	return bonus


## 从源容器复制内容；必须由复制体调用，`_new_contents()` 才会用复制体的实例 id
func _clone_contents_from(source: ContainerData) -> ContainerData:
	var copy := _new_contents()
	if source == null:
		return copy
	for item in source.items:
		if item == null:
			continue
		var grids := source.find_grids_by_item_data(item)
		if grids.is_empty():
			continue
		var cloned := item.make_instance()
		if copy.try_add_to_grid(cloned, ContainerData.anchor_of(grids)).is_empty():
			if copy.add_item(cloned).is_empty():
				push_warning("魂器「%s」复制时放不下魂灵「%s」" % [item_name, cloned.item_name])
	return copy


## 每个魂器实例用自己的容器名，避免两个实例共用同一份数据
func _new_contents() -> ContainerData:
	var types: Array[String] = ["SOUL"]
	var container_name := "vessel_%d" % get_instance_id()
	return ContainerData.new(
		container_name, container_columns, container_rows, types
	)
