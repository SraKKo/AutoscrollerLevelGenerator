class_name SharedLevelTopologyGenerator
extends RefCounted

const LEVEL_UPPER := 136
const LEVEL_MIDDLE := 408
const LEVEL_LOWER := 680
const GRAPH_LEVEL_UPPER := 180.0
const GRAPH_LEVEL_MIDDLE := 420.0
const GRAPH_LEVEL_LOWER := 660.0
const GRAPH_COLUMN_STEP := 220.0

var rng := RandomNumberGenerator.new()
var next_node_id := 0
var graph_nodes: Array[Dictionary] = []
var graph: Dictionary = {}
var graph_branches: Array[Dictionary] = []

func generate(
	seed_value: int,
	level_size: int = 12,
	branch_chance: float = 0.68,
	max_consecutive_straights: int = 2
) -> Dictionary:
	rng.seed = seed_value
	var modules: Array[Dictionary] = []
	var estimated_chunk_count := 1
	var branch_count := 0
	var consecutive_straights := 0
	var branch_target: int = clampi(int(ceil(float(level_size) / 6.0)), 1, 8)
	var target_before_finish: int = maxi(level_size - 1, 6)

	while estimated_chunk_count < target_before_finish:
		var must_branch: bool = branch_count < branch_target or consecutive_straights >= max_consecutive_straights
		if must_branch or rng.randf() < branch_chance:
			var branch_module: Dictionary = _create_branch_module(modules.size())
			modules.append(branch_module)
			estimated_chunk_count += int(branch_module["chunk_cost"])
			branch_count += 1
			consecutive_straights = 0
		else:
			var corridor_kind: String = _random_corridor_kind()
			modules.append({"type": "corridor", "kind": corridor_kind})
			estimated_chunk_count += 1
			if corridor_kind == "StraightRoom":
				consecutive_straights += 1
			else:
				consecutive_straights = 0

	var graph_data: Dictionary = _build_graph(modules)
	return {
		"seed": seed_value,
		"level_size": level_size,
		"modules": modules,
		"nodes": graph_data["nodes"],
		"graph": graph_data["graph"],
		"branches": graph_data["branches"],
		"start_id": graph_data["start_id"],
		"goal_id": graph_data["goal_id"],
		"dead_end_count": graph_data["dead_end_count"],
		"alternate_route_count": graph_data["alternate_route_count"],
		"validation": {},
	}

func _create_branch_module(module_index: int) -> Dictionary:
	var levels: Array[int] = [LEVEL_UPPER, LEVEL_MIDDLE, LEVEL_LOWER]
	var dead_level: int = levels[rng.randi_range(0, levels.size() - 1)]
	var good_level: int = LEVEL_MIDDLE
	var maybe_level: int = LEVEL_LOWER

	if dead_level == LEVEL_MIDDLE:
		if rng.randf() < 0.5:
			good_level = LEVEL_UPPER
			maybe_level = LEVEL_LOWER
		else:
			good_level = LEVEL_LOWER
			maybe_level = LEVEL_UPPER
	elif dead_level == LEVEL_LOWER:
		maybe_level = LEVEL_UPPER

	var triple_length: int = rng.randi_range(1, 2)
	var use_triple_cross: bool = rng.randf() < 0.72
	var closing_dead_level: int = _swap_upper_lower(dead_level) if use_triple_cross else dead_level
	var pair_length: int = rng.randi_range(1, 2)
	var pair_crossings: Array[bool] = []
	var used_crossing: bool = use_triple_cross

	for index in range(pair_length):
		var use_crossing: bool = rng.randf() < 0.72
		if not used_crossing and index == pair_length - 1:
			use_crossing = true
		pair_crossings.append(use_crossing)
		used_crossing = used_crossing or use_crossing

	return {
		"type": "branch",
		"module_index": module_index,
		"dead_level": dead_level,
		"good_level": good_level,
		"maybe_level": maybe_level,
		"closing_dead_level": closing_dead_level,
		"triple_length": triple_length,
		"use_triple_cross": use_triple_cross,
		"pair_length": pair_length,
		"pair_crossings": pair_crossings,
		"chunk_cost": 3 + triple_length + pair_length,
	}

func _build_graph(modules: Array[Dictionary]) -> Dictionary:
	next_node_id = 0
	graph_nodes.clear()
	graph.clear()
	graph_branches.clear()

	var current_x := 100.0
	var current_id: int = _create_graph_node(Vector2(current_x, GRAPH_LEVEL_MIDDLE), "start")

	for module_index in range(modules.size()):
		var module: Dictionary = modules[module_index]
		if module["type"] == "corridor":
			current_x += GRAPH_COLUMN_STEP
			var corridor_id: int = _create_graph_node(Vector2(current_x, GRAPH_LEVEL_MIDDLE), "normal")
			_add_graph_edge(current_id, corridor_id)
			current_id = corridor_id
		else:
			var branch_result: Dictionary = _append_graph_branch(current_id, current_x, module, module_index)
			current_id = int(branch_result["current_id"])
			current_x = float(branch_result["current_x"])

	current_x += GRAPH_COLUMN_STEP
	var goal_id: int = _create_graph_node(Vector2(current_x, GRAPH_LEVEL_MIDDLE), "goal")
	_add_graph_edge(current_id, goal_id)
	return {
		"nodes": graph_nodes.duplicate(true),
		"graph": graph.duplicate(true),
		"branches": graph_branches.duplicate(true),
		"start_id": 0,
		"goal_id": goal_id,
		"dead_end_count": graph_branches.size(),
		"alternate_route_count": graph_branches.size(),
	}

func _append_graph_branch(
	from_id: int,
	from_x: float,
	module: Dictionary,
	module_index: int
) -> Dictionary:
	var split_x: float = from_x + GRAPH_COLUMN_STEP
	var split_id: int = _create_graph_node(Vector2(split_x, GRAPH_LEVEL_MIDDLE), "split")
	_add_graph_edge(from_id, split_id)

	var route_x: float = split_x + GRAPH_COLUMN_STEP
	var good_id: int = _create_graph_node(Vector2(route_x, _graph_y(int(module["good_level"]))), "route")
	var maybe_id: int = _create_graph_node(Vector2(route_x, _graph_y(int(module["maybe_level"]))), "route")
	var dead_id: int = _create_graph_node(Vector2(route_x, _graph_y(int(module["dead_level"]))), "dead_end")
	var maybe_step_id: int = _create_graph_node(
		Vector2(route_x + GRAPH_COLUMN_STEP, _graph_y(int(module["maybe_level"]))),
		"alternate"
	)
	var merge_x: float = route_x + GRAPH_COLUMN_STEP * 2.0
	var merge_id: int = _create_graph_node(Vector2(merge_x, GRAPH_LEVEL_MIDDLE), "merge")

	graph[split_id] = [good_id, maybe_id, dead_id]
	_add_graph_edge(good_id, merge_id)
	_add_graph_edge(maybe_id, maybe_step_id)
	_add_graph_edge(maybe_step_id, merge_id)
	graph_branches.append({
		"module_index": module_index,
		"split_id": split_id,
		"routes": [
			{"route_id": good_id, "level": module["good_level"]},
			{"route_id": maybe_id, "level": module["maybe_level"]},
			{"route_id": dead_id, "level": module["dead_level"]},
		],
	})
	return {"current_id": merge_id, "current_x": merge_x}

func _create_graph_node(center: Vector2, node_type: String) -> int:
	var node_id: int = next_node_id
	next_node_id += 1
	graph_nodes.append({"id": node_id, "center": center, "type": node_type})
	graph[node_id] = []
	return node_id

func _add_graph_edge(from_id: int, to_id: int) -> void:
	(graph[from_id] as Array).append(to_id)

func _random_corridor_kind() -> String:
	var options: Array[String] = ["StraightRoom", "ZigZagUp", "ZigZagDown"]
	return options[rng.randi_range(0, options.size() - 1)]

func _swap_upper_lower(level: int) -> int:
	if level == LEVEL_UPPER:
		return LEVEL_LOWER
	if level == LEVEL_LOWER:
		return LEVEL_UPPER
	return LEVEL_MIDDLE

func _graph_y(level: int) -> float:
	if level == LEVEL_UPPER:
		return GRAPH_LEVEL_UPPER
	if level == LEVEL_LOWER:
		return GRAPH_LEVEL_LOWER
	return GRAPH_LEVEL_MIDDLE
