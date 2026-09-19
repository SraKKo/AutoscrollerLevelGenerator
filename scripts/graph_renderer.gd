class_name AbstractGraphRenderer
extends Node2D

const NODE_RADIUS := 28.0

var level: Dictionary = {}

func display_level(level_data: Dictionary) -> void:
	level = level_data
	queue_redraw()

func get_node_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if level.is_empty():
		return positions

	for node_data in level["nodes"] as Array:
		var node: Dictionary = node_data as Dictionary
		positions.append(node["center"] as Vector2)
	return positions

func get_node_size() -> Vector2:
	return Vector2(NODE_RADIUS * 2.0, NODE_RADIUS * 2.0)

func _draw() -> void:
	if level.is_empty():
		return

	var nodes_by_id: Dictionary = _nodes_by_id()
	var path_edges: Dictionary = _path_edges()
	var route_labels: Dictionary = _route_labels()
	var graph: Dictionary = level["graph"] as Dictionary

	for from_id in graph:
		for to_id in graph[from_id] as Array:
			var from_node: Dictionary = nodes_by_id[from_id] as Dictionary
			var to_node: Dictionary = nodes_by_id[to_id] as Dictionary
			var edge_key := _edge_key(int(from_id), int(to_id))
			var route_label: String = str(route_labels.get(int(to_id), ""))
			var edge_color := _edge_color(to_node, path_edges.has(edge_key), route_label)
			var edge_width := 7.0 if path_edges.has(edge_key) else 3.0
			draw_line(from_node["center"] as Vector2, to_node["center"] as Vector2, edge_color, edge_width)

	var validation: Dictionary = level["validation"] as Dictionary
	var visited: Array = validation["visit_order"] as Array
	for node_data in level["nodes"] as Array:
		var node: Dictionary = node_data as Dictionary
		var node_id: int = int(node["id"])
		var center: Vector2 = node["center"] as Vector2
		var route_label: String = str(route_labels.get(node_id, ""))
		var node_color: Color = _node_color(node, visited.has(node_id), route_label)
		draw_circle(center, NODE_RADIUS, node_color)
		draw_circle(center, NODE_RADIUS, Color("#e2e8f0"), false, 3.0)

		var label: String = str(node_id)
		if route_labels.has(node_id):
			label = str(route_labels[node_id])
		elif node["type"] == "start":
			label = "S"
		elif node["type"] == "goal":
			label = "G"
		_draw_centered_label(center, label)

func _nodes_by_id() -> Dictionary:
	var result: Dictionary = {}
	for node_data in level["nodes"] as Array:
		var node: Dictionary = node_data as Dictionary
		result[int(node["id"])] = node
	return result

func _path_edges() -> Dictionary:
	var result: Dictionary = {}
	var validation: Dictionary = level["validation"] as Dictionary
	var path: Array = validation["path"] as Array
	for index in range(path.size() - 1):
		result[_edge_key(int(path[index]), int(path[index + 1]))] = true
	return result

func _route_labels() -> Dictionary:
	var labels: Dictionary = {}
	var validation: Dictionary = level["validation"] as Dictionary
	var path: Array = validation["path"] as Array
	var graph: Dictionary = level["graph"] as Dictionary
	var goal_id: int = int(level["goal_id"])

	for branch_data in level["branches"] as Array:
		var branch: Dictionary = branch_data as Dictionary
		for route_data in branch["routes"] as Array:
			var route: Dictionary = route_data as Dictionary
			var route_id: int = int(route["route_id"])
			if path.has(route_id):
				labels[route_id] = "Y"
			elif _can_reach_goal(graph, route_id, goal_id):
				labels[route_id] = "M"
			else:
				labels[route_id] = "N"
	return labels

func _can_reach_goal(graph: Dictionary, start_id: int, goal_id: int) -> bool:
	var result: Dictionary = PlatformGraphValidator.validate_path(
		graph, start_id, goal_id, PlatformGraphValidator.METHOD_BFS
	)
	return bool(result["playable"])

func _edge_color(to_node: Dictionary, is_path: bool, route_label: String) -> Color:
	if is_path:
		return Color("#22c55e")
	if route_label == "N" or to_node["type"] == "dead_end":
		return Color("#ef4444")
	if route_label == "M" or to_node["type"] == "alternate":
		return Color("#f59e0b")
	return Color("#64748b")

func _node_color(node: Dictionary, was_visited: bool, route_label: String) -> Color:
	if route_label == "Y":
		return Color("#16a34a")
	if route_label == "M":
		return Color("#d97706")
	if route_label == "N":
		return Color("#dc2626")
	if node["type"] == "start":
		return Color("#16a34a")
	if node["type"] == "goal":
		return Color("#f59e0b")
	if node["type"] == "dead_end":
		return Color("#dc2626")
	if node["type"] == "split":
		return Color("#0ea5e9")
	if node["type"] == "merge":
		return Color("#14b8a6")
	return Color("#8b5cf6") if was_visited else Color("#475569")

func _draw_centered_label(center: Vector2, label: String) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 16
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x * 0.5, text_size.y * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _edge_key(from_id: int, to_id: int) -> String:
	return "%s:%s" % [from_id, to_id]
