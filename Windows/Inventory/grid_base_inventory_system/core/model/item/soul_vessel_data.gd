extends ItemData
class_name SoulVesselData

## 魂器类型；与 ContainerData.vessel_kind 的过滤值对应。
## COMBAT 可以装进角色魂器网格；TOOL 只能放在背包/仓库。
@export_enum("COMBAT", "TOOL") var vessel_kind: String = "COMBAT"
## 内部容器列数
@export var container_columns: int = 6
## 内部容器行数
@export var container_rows: int = 2
## tooltip 效果段落；分隔线由格式化器插入
@export var tooltip_blocks: Array[String] = []
## 对容器内魂灵生效的效果；当前只实现直接伤害加成
@export var effects: Array[SoulVesselEffect] = []

var contents: ContainerData


func make_instance() -> ItemData:
	var copy := duplicate() as SoulVesselData
	copy.contents = copy._clone_contents_from(contents)
	return copy


func activate() -> bool:
	return true


func container_kind_tag() -> String:
	return vessel_kind


func ensure_contents() -> ContainerData:
	if contents == null:
		contents = _new_contents()
	return contents


func soul_damage_bonus() -> float:
	var bonus := 0.0
	for effect in effects:
		if effect != null and effect.stat == SoulVesselEffect.Stat.DAMAGE_BONUS:
			bonus += effect.value
	return bonus


static func combat_vessels_in(container: ContainerData) -> Array[SoulVesselData]:
	var vessels: Array[SoulVesselData] = []
	if container == null:
		return vessels
	for item in container.items:
		if not item is SoulVesselData:
			continue
		var vessel := item as SoulVesselData
		if vessel.vessel_kind == "COMBAT":
			vessels.append(vessel)
	vessels.sort_custom(func (a: SoulVesselData, b: SoulVesselData) -> bool:
		var a_anchor := _anchor_in(container, a)
		var b_anchor := _anchor_in(container, b)
		if a_anchor.y == b_anchor.y:
			return a_anchor.x < b_anchor.x
		return a_anchor.y < b_anchor.y
	)
	return vessels


static func combat_souls_in(container: ContainerData) -> Array[SoulData]:
	var souls: Array[SoulData] = []
	for vessel in combat_vessels_in(container):
		for item in vessel.ensure_contents().items:
			if item is SoulData:
				souls.append(item as SoulData)
	return souls


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


func _new_contents() -> ContainerData:
	var types: Array[String] = ["SOUL"]
	var container_name := "vessel_%d" % get_instance_id()
	return ContainerData.new(
		container_name, container_columns, container_rows, types
	)


static func _anchor_in(container: ContainerData, vessel: SoulVesselData) -> Vector2i:
	var grids := container.find_grids_by_item_data(vessel)
	if grids.is_empty():
		return Vector2i(1 << 20, 1 << 20)
	return ContainerData.anchor_of(grids)
