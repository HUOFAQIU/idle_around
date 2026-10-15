## 走一步：给"我在哪、要去哪、哪些格子不能站"，返回下一步该站哪格。
##
## 现在是贪心：六个邻居里挑离目标最近的那个，被挡就原地等（排队往里走）。
## 以后要换 A*、绕障碍、绕开别的怪，只改这一个文件，调用方不用动。

class_name HexStep extends RefCounted


## 返回下一步的格子；已经在目标格、或者无路可走时返回原格
## occupied：被占的格子（值为 true）
## is_walkable：可选，判断格子本身能不能站（比如地图外）；不传就不检查
static func next_step(from: Vector2i, goal: Vector2i, occupied: Dictionary, is_walkable: Callable = Callable()) -> Vector2i:
	if from == goal:
		return from

	var best := from
	var best_distance := Hex.distance(from, goal)

	for neighbor in Hex.neighbors(from):
		if occupied.has(neighbor):
			continue
		if is_walkable.is_valid() and not is_walkable.call(neighbor):
			continue
		var distance := Hex.distance(neighbor, goal)
		if distance < best_distance:
			best_distance = distance
			best = neighbor

	return best
