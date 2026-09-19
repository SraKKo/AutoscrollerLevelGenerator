extends Node2D

const TILE_SIZE := Vector2(1088.0, 816.0)
const SCREEN_ORIGIN := Vector2.ZERO

const LEVEL_UPPER := 136
const LEVEL_MIDDLE := 408
const LEVEL_LOWER := 680
const MAX_CONSECUTIVE_STRAIGHTS := 2
const BRANCH_CHANCE := 0.68

@export var random_seed := 54321
@export_range(7, 30, 1) var room_count := 12

var rng := RandomNumberGenerator.new()
var level: Dictionary = {}
var render_chunks: Array = []
var use_dfs := false
var generated_branches: Array[Dictionary] = []

@onready var rooms: ChunkRoomsRenderer = $Rooms
@onready var graph_debug: ChunkGraphDebug = $GraphDebug
@onready var route_signs: ChunkRouteSigns = $RouteSigns
@onready var camera_control: LevelCameraControl = $CameraControl
@onready var hud: ChunkDemoHud = $HUD

func _ready() -> void:
	_generate_rooms(random_seed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("generate_level"):
		_generate_rooms(int(Time.get_unix_time_from_system()))
	elif event.is_action_pressed("toggle_validation_method"):
		use_dfs = not use_dfs
		_revalidate()

func _generate_rooms(seed_value: int) -> void:
	random_seed = seed_value
	rng.seed = random_seed
	var chunk_names: Array[String] = _generate_chunk_sequence()
	_build_render_chunks(chunk_names)
	level = _build_level_graph(chunk_names)
	_render_rooms()
	graph_debug.update_chunks(render_chunks)
	_revalidate()

func _generate_chunk_sequence() -> Array[String]:
	var chunks: Array[String] = ["Start"]
	var current_level: int = LEVEL_MIDDLE
	var branch_count: int = 0
	var branch_target: int = clampi(int(ceil(float(room_count) / 6.0)), 1, 5)
	var consecutive_straights: int = 0
	var target_before_finish: int = maxi(room_count - 1, 6)
	generated_branches.clear()

	while chunks.size() < target_before_finish:
		if branch_count < branch_target:
			if current_level != LEVEL_MIDDLE:
				chunks.append(_chunk_to_middle(current_level))
				current_level = LEVEL_MIDDLE
				consecutive_straights = 0
				continue

			current_level = _append_triple_branch_section(chunks)
			branch_count += 1
			consecutive_straights = 0
			continue

		var roll: float = rng.randf()
		if current_level == LEVEL_MIDDLE:
			if roll < BRANCH_CHANCE:
				current_level = _append_triple_branch_section(chunks)
				branch_count += 1
				consecutive_straights = 0
			elif consecutive_straights < MAX_CONSECUTIVE_STRAIGHTS and roll < 0.82:
				var middle_chunk: String = _random_middle_corridor()
				chunks.append(middle_chunk)
				if middle_chunk == "StraightRoom":
					consecutive_straights += 1
				else:
					consecutive_straights = 0
			elif roll < 0.91:
				chunks.append("RiseToUpper")
				current_level = LEVEL_UPPER
				consecutive_straights = 0
			else:
				chunks.append("DropToLower")
				current_level = LEVEL_LOWER
				consecutive_straights = 0
		elif current_level == LEVEL_UPPER:
			if consecutive_straights < MAX_CONSECUTIVE_STRAIGHTS and roll < 0.24:
				chunks.append("StraightUpper")
				consecutive_straights += 1
			elif roll < 0.48:
				chunks.append("GoingDown")
				current_level = LEVEL_LOWER
				consecutive_straights = 0
			else:
				chunks.append("UpperToMiddle")
				current_level = LEVEL_MIDDLE
				consecutive_straights = 0
		else:
			if consecutive_straights < MAX_CONSECUTIVE_STRAIGHTS and roll < 0.24:
				chunks.append("StraightLower")
				consecutive_straights += 1
			elif roll < 0.48:
				chunks.append("GoingUp")
				current_level = LEVEL_UPPER
				consecutive_straights = 0
			else:
				chunks.append("LowerToMiddle")
				current_level = LEVEL_MIDDLE
				consecutive_straights = 0

	if current_level != LEVEL_MIDDLE:
		chunks.append(_chunk_to_middle(current_level))

	chunks.append("Finish")
	return chunks

func _append_triple_branch_section(chunks: Array[String]) -> int:
	var split_index: int = chunks.size()
	chunks.append("TripleSplit")

	var levels: Array[int] = [LEVEL_UPPER, LEVEL_MIDDLE, LEVEL_LOWER]
	var dead_level: int = levels[rng.randi_range(0, levels.size() - 1)]
	var good_level: int = LEVEL_MIDDLE
	var maybe_level: int = LEVEL_LOWER
	if dead_level == LEVEL_UPPER:
		good_level = LEVEL_MIDDLE
		maybe_level = LEVEL_LOWER
	elif dead_level == LEVEL_MIDDLE:
		if rng.randf() < 0.5:
			good_level = LEVEL_UPPER
			maybe_level = LEVEL_LOWER
		else:
			good_level = LEVEL_LOWER
			maybe_level = LEVEL_UPPER
	else:
		good_level = LEVEL_MIDDLE
		maybe_level = LEVEL_UPPER

	var triple_length: int = rng.randi_range(1, 2)
	var crossed_outer_routes := false
	for index in range(triple_length):
		if index == 0 and rng.randf() < 0.72:
			chunks.append("CrossTriple")
			crossed_outer_routes = true
		else:
			chunks.append("TripleStraight")

	var closing_dead_level: int = dead_level
	if crossed_outer_routes:
		closing_dead_level = _swap_upper_lower(dead_level)

	var pair_chunk: String = "MiddleLowerStraight"
	var crossing_chunk: String = "CrossMiddleLower"
	var merge_chunk: String = "MergeMiddleLower"

	if closing_dead_level == LEVEL_UPPER:
		chunks.append("TripleCloseUpper")
		pair_chunk = "MiddleLowerStraight"
		crossing_chunk = "CrossMiddleLower"
		merge_chunk = "MergeMiddleLower"
	elif closing_dead_level == LEVEL_MIDDLE:
		chunks.append("TripleCloseMiddle")
		pair_chunk = "DoubleStraight"
		crossing_chunk = "CrossX"
		merge_chunk = "MergeRoom"
	else:
		chunks.append("TripleCloseLower")
		pair_chunk = "UpperMiddleStraight"
		crossing_chunk = "CrossUpperMiddle"
		merge_chunk = "MergeUpperMiddle"

	var pair_length: int = rng.randi_range(1, 2)
	var used_crossing: bool = crossed_outer_routes
	for index in range(pair_length):
		var must_use_crossing: bool = not used_crossing and index == pair_length - 1
		if must_use_crossing or rng.randf() < 0.72:
			chunks.append(crossing_chunk)
			used_crossing = true
		else:
			chunks.append(pair_chunk)

	var merge_index: int = chunks.size()
	chunks.append(merge_chunk)
	generated_branches.append({
		"split_index": split_index,
		"merge_index": merge_index,
		"good_level": good_level,
		"maybe_level": maybe_level,
		"dead_level": dead_level,
	})
	return LEVEL_MIDDLE

func _random_middle_corridor() -> String:
	var options: Array[String] = ["StraightRoom", "ZigZagUp", "ZigZagDown"]
	return options[rng.randi_range(0, options.size() - 1)]

func _swap_upper_lower(level: int) -> int:
	if level == LEVEL_UPPER:
		return LEVEL_LOWER
	if level == LEVEL_LOWER:
		return LEVEL_UPPER
	return LEVEL_MIDDLE

func _chunk_to_middle(current_level: int) -> String:
	return "UpperToMiddle" if current_level == LEVEL_UPPER else "LowerToMiddle"

func _build_render_chunks(chunk_names: Array[String]) -> void:
	render_chunks.clear()
	for index in range(chunk_names.size()):
		var chunk_name: String = chunk_names[index]
		render_chunks.append({
			"chunk_name": chunk_name,
			"world_position": SCREEN_ORIGIN + Vector2(float(index) * TILE_SIZE.x, 0.0),
		})

func _build_level_graph(chunk_names: Array[String]) -> Dictionary:
	var graph: Dictionary = {}
	var dead_end_ids: Array[int] = []
	var branches: Array[Dictionary] = []

	for index in range(chunk_names.size()):
		graph[index] = []
		if index < chunk_names.size() - 1:
			(graph[index] as Array).append(index + 1)

	var next_id: int = chunk_names.size()
	for branch_data in generated_branches:
		var generated_branch: Dictionary = branch_data as Dictionary
		var split_index: int = int(generated_branch["split_index"])
		var merge_index: int = int(generated_branch["merge_index"])
		var continuation_id: int = merge_index + 1

		var good_route_id: int = next_id
		next_id += 1
		var maybe_route_id: int = next_id
		next_id += 1
		var maybe_route_step_id: int = next_id
		next_id += 1
		var dead_end_id: int = next_id
		next_id += 1

		graph[good_route_id] = [continuation_id]
		graph[maybe_route_id] = [maybe_route_step_id]
		graph[maybe_route_step_id] = [continuation_id]
		graph[dead_end_id] = []
		graph[split_index] = [good_route_id, maybe_route_id, dead_end_id]
		dead_end_ids.append(dead_end_id)
		branches.append({
			"split_index": split_index,
			"routes": [
				{"route_id": good_route_id, "level": generated_branch["good_level"]},
				{"route_id": maybe_route_id, "level": generated_branch["maybe_level"]},
				{"route_id": dead_end_id, "level": generated_branch["dead_level"]},
			],
		})

	return {
		"seed": random_seed,
		"graph": graph,
		"start_id": 0,
		"goal_id": chunk_names.size() - 1,
		"dead_end_ids": dead_end_ids,
		"dead_end_count": dead_end_ids.size(),
		"alternate_route_count": branches.size(),
		"branches": branches,
		"validation": {},
	}

func _render_rooms() -> void:
	var room_positions: Array[Vector2] = rooms.rebuild(render_chunks)
	camera_control.fit_to_rooms(room_positions, rooms.get_scaled_room_size())

func _revalidate() -> void:
	if level.is_empty():
		return

	var method: String = PlatformGraphValidator.METHOD_DFS if use_dfs else PlatformGraphValidator.METHOD_BFS
	level["validation"] = PlatformGraphValidator.validate_path(
		level["graph"] as Dictionary,
		int(level["start_id"]),
		int(level["goal_id"]),
		method
	)
	route_signs.update_signs(level, render_chunks)
	hud.update_level(level, use_dfs)
