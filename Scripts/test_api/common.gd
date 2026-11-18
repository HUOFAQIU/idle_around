extends RefCounted
## TestAPI 各域共用的场景树查询。
##
## 只给 Scripts/test_api/ 下的模块用，不对外转发。

## 当前场景根；没有 current_scene 时退回树根
static func scene_root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root


## 在场景根下找第一个指定类型的节点；node_name 非空时同时匹配名字
static func find_node_in_scene(type : Variant, node_name : StringName = &"") -> Node:
	var root := scene_root()
	if root == null:
		return null
	for node in root.find_children("*", "", true, false):
		if not is_instance_of(node, type):
			continue
		if node_name != &"" and node.name != node_name:
			continue
		return node
	return null


## target："player" / "enemy" / 单位名
static func find_unit(target : String) -> BattleUnit:
	var root := scene_root()
	if root == null:
		return null
	for node in root.find_children("*", "", true, false):
		if not node is BattleUnit:
			continue
		var unit := node as BattleUnit
		if unit.is_dead or unit.asc == null:
			continue
		if target == "player" and unit.team == BattleUnit.Team.PLAYER:
			return unit
		if target == "enemy" and unit.team == BattleUnit.Team.ENEMY:
			return unit
		if unit.unit_name == target:
			return unit
	return null
