class_name AbstractGraphLevelGenerator
extends Node

const LEVEL_UPPER := 180.0
const LEVEL_MIDDLE := 420.0
const LEVEL_LOWER := 660.0
const COLUMN_STEP := 220.0

@export_range(7, 60, 1) var target_node_count := 24
@export_range(0.0, 1.0, 0.01) var branch_chance := 0.68
@export_range(1, 2, 1) var max_consecutive_straights := 2

var rng := RandomNumberGenerator.new()
var nodes: Array[Dictionary] = []
var graph: Dictionary = {}
var branches: Array[Dictionary] = []
var next_id := 0

func generate(seed_value: int) -> Dictionary:
	rng.seed = seed_value
	nodes.clear()
	graph.clear()
	branches.clear()
	next_id = 0

	var current_x := 100.0
	var current_id: int = _create_node(Vector2(current_x, LEVEL_MIDDLE), "start")
	var branch_count := 0
	var consecutive_straights := 0
	var branch_target: int = clampi(int(ceil(float(target_node_count) / 6.0)), 1, 8)

	while nodes.size() < target_node_count - 1:
		var must_branch: bool = branch_count < branch_target or consecutive_straights >= max_consecutive_straights
		if must_branch or rng.randf() < branch_chance:
			var branch_result: Dictionary = _append_branch(current_id, current_x)
			current_id = int(branch_result["current_id"])
			current_x = float(branch_result["current_x"])
			branch_count += 1
			consecutive_straights = 0
		else:
			current_x += COLUMN_STEP
			var straight_id: int = _create_node(Vector2(current_x, LEVEL_MIDDLE), "normal")
			_add_edge(current_id, straight_id)
			current_id = straight_id
			consecutive_straights += 1

	current_x += COLUMN_STEP
	var goal_id: int = _create_node(Vector2(current_x, LEVEL_MIDDLE), "goal")
	_add_edge(current_id, goal_id)

	return {
		"seed": seed_value,
		"nodes": nodes.duplicate(true),
		"graph": graph.duplicate(true),
		"branches": branches.duplicate(true),
		"start_id": 0,
		"goal_id": goal_id,
		"dead_end_count": branches.size(),
		"alternate_route_count": branches.size(),
		"validation": {},
	}

func _append_branch(from_id: int, from_x: float) -> Dictionary:
	var split_x: float = from_x + COLUMN_STEP
	var split_id: int = _create_node(Vector2(split_x, LEVEL_MIDDLE), "split")
	_add_edge(from_id, split_id)

	var levels: Array[float] = [LEVEL_UPPER, LEVEL_MIDDLE, LEVEL_LOWER]
	var dead_level: float = levels[rng.randi_range(0, levels.size() - 1)]
	var remaining_levels: Array[float] = []
	for level_y in levels:
		if level_y != dead_level:
			remaining_levels.append(level_y)

	var good_level: float = remaining_levels[0]
	var maybe_level: float = remaining_levels[1]
	if remaining_levels.has(LEVEL_MIDDLE):
		good_level = LEVEL_MIDDLE
		maybe_level = remaining_levels[0] if remaining_levels[1] == LEVEL_MIDDLE else remaining_levels[1]
	elif rng.randf() < 0.5:
		good_level = remaining_levels[1]
		maybe_level = remaining_levels[0]

	var route_x: float = split_x + COLUMN_STEP
	var good_id: int = _create_node(Vector2(route_x, good_level), "route")
	var maybe_id: int = _create_node(Vector2(route_x, maybe_level), "route")
	var dead_id: int = _create_node(Vector2(route_x, dead_level), "dead_end")
	var maybe_step_id: int = _create_node(Vector2(route_x + COLUMN_STEP, maybe_level), "alternate")
	var merge_x: float = route_x + COLUMN_STEP * 2.0
	var merge_id: int = _create_node(Vector2(merge_x, LEVEL_MIDDLE), "merge")

	graph[split_id] = [good_id, maybe_id, dead_id]
	_add_edge(good_id, merge_id)
	_add_edge(maybe_id, maybe_step_id)
	_add_edge(maybe_step_id, merge_id)
	branches.append({
		"split_id": split_id,
		"routes": [
			{"route_id": good_id, "kind": "candidate"},
			{"route_id": maybe_id, "kind": "candidate"},
			{"route_id": dead_id, "kind": "dead_end"},
		],
	})

	return {"current_id": merge_id, "current_x": merge_x}

func _create_node(center: Vector2, node_type: String) -> int:
	var node_id: int = next_id
	next_id += 1
	nodes.append({
		"id": node_id,
		"center": center,
		"type": node_type,
	})
	graph[node_id] = []
	return node_id

func _add_edge(from_id: int, to_id: int) -> void:
	(graph[from_id] as Array).append(to_id)
