## 容器的存档域：仓库各页 + 四个魂灵格，以及放不进世界的孤儿记录。
##
## 容器未注册时不读不写（由 SaveManager 检查 missing_containers）；
## 未知容器的原始记录原样保留，避免后续写档丢物品。
class_name ContainerSaveParticipant extends SaveParticipant

## 本次读档从磁盘带回来的孤儿记录数；只重试这些，不重试本次新产生的
var _restore_count: int = 0
## 因 mod 缺失/容器缺失/容器满而暂时放不进世界的物品记录；写档时原样保留
var _orphaned_records: Array[Dictionary] = []


## 存档必须覆盖的容器：仓库各页 + 四个魂灵格
func expected_containers() -> Array[String]:
	var names: Array[String] = []
	for page in Warehouse.PAGE_COUNT:
		names.append(Warehouse.page_name(page))
	names.append_array(ContainerIds.soul_cells())
	return names


## 期望容器里当前还没注册的项；为空表示可以安全读写档
func missing_containers() -> Array[String]:
	var missing: Array[String] = []
	for container_name in expected_containers():
		if not GBIS.inventory_names.has(container_name):
			missing.append(container_name)
	return missing


func containers_ready() -> bool:
	return missing_containers().is_empty()


## 当前存档里因 mod 缺失/放不下而保留的原始记录
func get_orphaned_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _orphaned_records:
		result.append(entry.duplicate(true))
	return result


func collect_into(document: Dictionary) -> void:
	var containers := {}
	for inv_name in expected_containers():
		var container := ContainerRepository.instance.get_container(inv_name)
		if container == null:
			continue
		var records := SaveCodec.encode_container(container)
		if not records.is_empty():
			containers[inv_name] = records
	document[SaveDocument.KEY_CONTAINERS] = containers

	var detached: Array = []
	if GBIS.has_moving_item():
		var record := SaveCodec.encode_item(GBIS.moving_item_service.moving_item)
		if not record.is_empty():
			detached.append(record)
	document[SaveDocument.KEY_DETACHED] = detached

	if not _orphaned_records.is_empty():
		var orphaned: Array = []
		for entry in _orphaned_records:
			orphaned.append(entry.duplicate(true))
		document[SaveDocument.KEY_ORPHANED] = orphaned


func apply_from(document: Dictionary, _has_disk_data: bool) -> bool:
	_orphaned_records = _read_orphaned_records(document)
	_restore_count = _orphaned_records.size()
	_clear_containers()
	_apply_containers(document)
	return false


## 读档末尾再试一次存档里带回来的保留物品；本次新产生的保留记录不重复尝试
func finish_load() -> bool:
	var remaining: Array[Dictionary] = []
	var index := 0
	for entry in _orphaned_records:
		if index >= _restore_count:
			remaining.append(entry)
			index += 1
			continue
		index += 1
		var record: Variant = entry.get("record", {})
		if not record is Dictionary:
			remaining.append(entry)
			continue
		var record_data := record as Dictionary
		var item := SaveCodec.decode_item(record_data)
		if item == null:
			remaining.append(entry)
			continue
		var container_name := String(entry.get("container", ""))
		if _try_restore_item(item, record_data, container_name):
			continue
		remaining.append(entry)
	_orphaned_records = remaining
	return false


func _clear_containers() -> void:
	for inv_name in expected_containers():
		var container := ContainerRepository.instance.get_container(inv_name)
		if container != null:
			container.clear()


func _apply_containers(data: Dictionary) -> void:
	var containers_data: Variant = data.get(SaveDocument.KEY_CONTAINERS, {})
	if containers_data is Dictionary:
		for key in containers_data:
			var container_name := String(key)
			var records: Variant = containers_data[key]
			var container := ContainerRepository.instance.get_container(container_name)
			if container == null:
				if records is Array:
					var preserved := _preserve_unknown_container(container_name, records as Array)
					push_warning("存档：容器不存在 %s，已保留 %d 件物品到 orphaned" % [container_name, preserved])
				else:
					push_warning("存档：容器不存在 %s，且数据格式不对，已跳过" % container_name)
				continue
			if not records is Array:
				push_warning("存档：%s 的数据格式不对" % container_name)
				continue
			_apply_container(container, records)
	var detached: Variant = data.get(SaveDocument.KEY_DETACHED, [])
	if detached is Array:
		for record in detached:
			if not record is Dictionary:
				continue
			var record_data := record as Dictionary
			var item := SaveCodec.decode_item(record_data)
			if item == null:
				_orphaned_records.append(_make_orphaned_entry("", record_data))
				continue
			if not Warehouse.add_item(item):
				_orphaned_records.append(_make_orphaned_entry("", record_data))
				push_warning("存档：拖拽中的物品无法放回仓库，已保留到 orphaned")


## 未知容器的原始记录原样保留，避免之后写档时丢失
func _preserve_unknown_container(container_name: String, records: Array) -> int:
	var preserved := 0
	for record in records:
		if record is Dictionary:
			_orphaned_records.append(_make_orphaned_entry(container_name, record))
			preserved += 1
	return preserved


func _apply_container(container: ContainerData, records: Array) -> void:
	records.sort_custom(SaveCodec.sort_records)
	for record in records:
		if not record is Dictionary:
			continue
		var record_data := record as Dictionary
		var item := SaveCodec.decode_item(record_data)
		if item == null:
			_orphaned_records.append(_make_orphaned_entry(container.container_name, record_data))
			continue
		var anchor := SaveCodec.anchor_from_record(record_data)
		if not container.try_add_to_grid(item, anchor).is_empty():
			continue
		if not container.add_item(item).is_empty():
			push_warning("存档：%s 的「%s」无法放回原格 %s，已放到第一个空位" % [container.container_name, item.item_name, anchor])
			continue
		if Warehouse.add_item(item):
			push_warning("存档：%s 的「%s」放不下，已转入仓库" % [container.container_name, item.item_name])
			continue
		_orphaned_records.append(_make_orphaned_entry(container.container_name, record_data))
		push_warning("存档：物品无处安放，已保留到 orphaned：%s" % item.item_name)


## 构造一条保留记录；container 为空表示原本在鼠标上
func _make_orphaned_entry(container_name: String, record: Dictionary) -> Dictionary:
	return {
		"container": container_name,
		"record": record.duplicate(true),
	}


func _read_orphaned_records(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw: Variant = data.get(SaveDocument.KEY_ORPHANED, [])
	if not raw is Array:
		return result
	for entry in raw:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _try_restore_item(item: ItemData, record: Dictionary, container_name: String) -> bool:
	if not container_name.is_empty():
		var container := ContainerRepository.instance.get_container(container_name)
		if container != null:
			var anchor := SaveCodec.anchor_from_record(record)
			if not container.try_add_to_grid(item, anchor).is_empty():
				return true
			if not container.add_item(item).is_empty():
				push_warning("存档：缺失内容「%s」已恢复到 %s 的空位" % [item.item_name, container_name])
				return true
	if Warehouse.add_item(item):
		push_warning("存档：缺失内容「%s」已放回仓库" % item.item_name)
		return true
	return false
