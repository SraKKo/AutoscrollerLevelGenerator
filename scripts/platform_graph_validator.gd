class_name PlatformGraphValidator
extends RefCounted

const METHOD_BFS := "BFS"
const METHOD_DFS := "DFS"

static func build_reachability_graph(platforms: Array, jump_rules: Dictionary) -> Dictionary:
	var graph: Dictionary = {}
	for platform in platforms:
		graph[platform["id"]] = []

	for from_platform in platforms:
		for to_platform in platforms:
			if from_platform["id"] == to_platform["id"]:
				continue

			if _can_reach_platform(from_platform, to_platform, jump_rules):
				graph[from_platform["id"]].append(to_platform["id"])

	return graph

static func validate_path(graph: Dictionary, start_id: int, goal_id: int, method: String = METHOD_BFS) -> Dictionary:
	if method == METHOD_DFS:
		return _validate_dfs(graph, start_id, goal_id)

	return _validate_bfs(graph, start_id, goal_id)

static func _validate_bfs(graph: Dictionary, start_id: int, goal_id: int) -> Dictionary:
	var queue: Array = [start_id]
	var visited: Dictionary = {start_id: true}
	var came_from: Dictionary = {}
	var visit_order: Array = []

	while not queue.is_empty():
		var current: int = int(queue.pop_front())
		visit_order.append(current)

		if current == goal_id:
			return _result(true, _reconstruct_path(came_from, start_id, goal_id), visit_order)

		for next_id in graph.get(current, []):
			if visited.has(next_id):
				continue

			visited[next_id] = true
			came_from[next_id] = current
			queue.append(next_id)

	return _result(false, [], visit_order)

static func _validate_dfs(graph: Dictionary, start_id: int, goal_id: int) -> Dictionary:
	var stack: Array = [start_id]
	var visited: Dictionary = {}
	var came_from: Dictionary = {}
	var visit_order: Array = []

	while not stack.is_empty():
		var current: int = int(stack.pop_back())
		if visited.has(current):
			continue

		visited[current] = true
		visit_order.append(current)

		if current == goal_id:
			return _result(true, _reconstruct_path(came_from, start_id, goal_id), visit_order)

		var neighbours: Array = graph.get(current, [])
		for i in range(neighbours.size() - 1, -1, -1):
			var next_id: int = int(neighbours[i])
			if visited.has(next_id):
				continue

			if not came_from.has(next_id):
				came_from[next_id] = current
			stack.append(next_id)

	return _result(false, [], visit_order)

static func _can_reach_platform(from_platform: Dictionary, to_platform: Dictionary, jump_rules: Dictionary) -> bool:
	var from_center: Vector2 = from_platform["center"] as Vector2
	var to_center: Vector2 = to_platform["center"] as Vector2
	var horizontal_distance: float = abs(to_center.x - from_center.x)
	var vertical_delta: float = from_center.y - to_center.y
	var allowed_fall: float = float(jump_rules["max_drop_height"])
	var angle_tolerance: float = float(jump_rules.get("angle_tolerance", 4.0))
	var flat_tolerance: float = float(jump_rules.get("flat_tolerance", 4.0))

	if horizontal_distance > float(jump_rules["max_jump_distance"]):
		return false

	var is_diagonal_45: bool = abs(horizontal_distance - abs(vertical_delta)) <= angle_tolerance
	var is_flat: bool = abs(vertical_delta) <= flat_tolerance
	if not is_diagonal_45 and not is_flat:
		return false

	if vertical_delta > float(jump_rules["max_jump_height"]):
		return false

	if vertical_delta < -allowed_fall:
		return false

	return true

static func _reconstruct_path(came_from: Dictionary, start_id: int, goal_id: int) -> Array:
	var path: Array = [goal_id]
	var current: int = goal_id

	while current != start_id and came_from.has(current):
		current = int(came_from[current])
		path.push_front(current)

	return path

static func _result(playable: bool, path: Array, visit_order: Array) -> Dictionary:
	return {
		"playable": playable,
		"path": path,
		"visit_order": visit_order,
	}
