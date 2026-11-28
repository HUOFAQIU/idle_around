class_name ItemTooltipRegistry
extends RefCounted

const CONTAINER_IDS: GDScript = preload("res://scripts/container_ids.gd")

static var _entries: Array[Dictionary] = []
static var _defaults_loaded: bool = false


static func register(item_script: Script, builder: Callable) -> void:
	_ensure_defaults()
	if item_script == null or not builder.is_valid():
		return
	for entry in _entries:
		if entry["script"] == item_script:
			entry["builder"] = builder
			return
	_entries.push_front({"script": item_script, "builder": builder})


static func build(
	item_data: ItemData,
	container_name: String = "",
	format: TooltipText.Format = TooltipText.Format.PLAIN
) -> String:
	_ensure_defaults()
	if item_data == null:
		return ""
	for entry in _entries:
		var item_script := entry["script"] as Script
		if item_script != null and is_instance_of(item_data, item_script):
			var builder: Callable = entry["builder"]
			return String(builder.call(item_data, container_name, format))
	return ""


static func _ensure_defaults() -> void:
	if _defaults_loaded:
		return
	_defaults_loaded = true
	_entries = [
		{"script": SoulData, "builder": _build_soul},
		{"script": SoulVesselData, "builder": _build_vessel},
		{"script": MapItemData, "builder": _build_map},
		{"script": QuantityStoneData, "builder": _build_quantity_stone},
	]


static func _build_soul(
	item_data: ItemData,
	container_name: String,
	format: TooltipText.Format
) -> String:
	var soul := item_data as SoulData
	return SoulTooltip.build(soul, format, _soul_preview(soul, container_name))


static func _build_vessel(
	item_data: ItemData,
	_container_name: String,
	format: TooltipText.Format
) -> String:
	return VesselTooltip.build(item_data as SoulVesselData, format)


static func _build_map(
	item_data: ItemData,
	_container_name: String,
	format: TooltipText.Format
) -> String:
	return MapTooltip.build(item_data as MapItemData, format)


static func _build_quantity_stone(
	item_data: ItemData,
	_container_name: String,
	format: TooltipText.Format
) -> String:
	return QuantityStoneTooltip.build(item_data as QuantityStoneData, format)


static func _soul_preview(soul: SoulData, container_name: String) -> SoulDamagePreview:
	if container_name.is_empty():
		return null
	var container := ContainerRepository.instance.get_container(container_name)
	if container == null:
		return null
	var vessel := container.get_owner_item() as SoulVesselData
	if vessel == null or vessel.vessel_kind != "COMBAT":
		return null
	var runtime := SoulRuntimeDB.get_runtime(soul)
	if runtime != null:
		return SoulDamagePreview.for_soul(soul, runtime)
	var grid := ContainerRepository.instance.get_container(CONTAINER_IDS.VESSEL_GRID)
	return SoulDamagePreview.preview_for(soul, vessel, SoulVesselData.combat_souls_in(grid))
