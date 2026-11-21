extends Resource
class_name ContainerRepository

const PREFIX: String = "container_"

static var instance: ContainerRepository:
	get:
		if not instance:
			instance = ContainerRepository.new()
		return instance

## 所有背包数据
@export_storage var _container_data_map: Dictionary[String, ContainerData]
## 所有背包的快速移动关系
@export_storage var _quick_move_relations_map: Dictionary[String, Array]

func save() -> void:
	ResourceSaver.save(self, GBIS.current_save_path + PREFIX + GBIS.current_save_name)

func load() -> void:
	var saved_repository: ContainerRepository = load(GBIS.current_save_path + PREFIX + GBIS.current_save_name)
	if not saved_repository:
		return
	for inv_name in saved_repository._container_data_map.keys():
		_container_data_map[inv_name] = saved_repository._container_data_map[inv_name].deep_duplicate()
	_quick_move_relations_map = saved_repository._quick_move_relations_map.duplicate(true)

func add_container(inv_name: String, columns: int, rows: int, avilable_types: Array[String]) -> ContainerData:
	var inv = get_container(inv_name)
	if not inv:
		var new_container = ContainerData.new(inv_name, columns, rows, avilable_types)
		_container_data_map[inv_name] = new_container
		return new_container
	return inv

func get_container(inv_name: String) -> ContainerData:
	return _container_data_map.get(inv_name)


func register_container_data(container_name: String, container: ContainerData) -> void:
	if container == null:
		return
	container.container_name = container_name
	_container_data_map[container_name] = container


func remove_container(container_name: String) -> void:
	_container_data_map.erase(container_name)

func add_quick_move_relation(inv_name: String, target_inv_name: String) -> void:
	if _quick_move_relations_map.has(inv_name):
		var relations = _quick_move_relations_map[inv_name]
		relations.append(target_inv_name)
	else:
		var arr: Array[String] = [target_inv_name]
		_quick_move_relations_map[inv_name] = arr

func remove_quick_move_relation(inv_name: String, target_inv_name: String) -> void:
	if _quick_move_relations_map.has(inv_name):
		var relations = _quick_move_relations_map[inv_name]
		relations.erase(target_inv_name)

func get_quick_move_relations(inv_name: String) -> Array[String]:
	return _quick_move_relations_map.get(inv_name, [] as Array[String])
