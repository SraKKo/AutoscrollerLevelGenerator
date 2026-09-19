extends Node2D

const TILE_SIZE := Vector2(1088.0, 816.0)
const SCREEN_ORIGIN := Vector2.ZERO
const LEVEL_UPPER := 136
const LEVEL_MIDDLE := 408

@export var random_seed := 54321
@export_range(7, 30, 1) var room_count := 12
@export_range(0.0, 1.0, 0.01) var branch_chance := 0.68
@export_range(1, 2, 1) var max_consecutive_straights := 2

var topology_generator := SharedLevelTopologyGenerator.new()
var level: Dictionary = {}
var render_chunks: Array = []
var visual_split_indices: Dictionary = {}
var use_dfs := false

@onready var rooms: ChunkRoomsRenderer = $Rooms
@onready var graph_debug: ChunkGraphDebug = $GraphDebug
@onready var route_signs: ChunkRouteSigns = $RouteSigns
@onready var camera_control: LevelCameraControl = $CameraControl
@onready var hud: ChunkDemoHud = $HUD

func _ready() -> void:
	_generate_rooms(random_seed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("generate_level"):
		_generate_rooms(random_seed + 1)
	elif event.is_action_pressed("toggle_validation_method"):
		use_dfs = not use_dfs
		_revalidate()

func _generate_rooms(seed_value: int) -> void:
	random_seed = seed_value
	level = topology_generator.generate(
		random_seed,
		room_count,
		branch_chance,
		max_consecutive_straights
	)
	var chunk_names: Array[String] = _build_chunk_sequence(level["modules"] as Array)
	_apply_visual_split_indices()
	_build_render_chunks(chunk_names)
	_render_rooms()
	graph_debug.update_chunks(render_chunks)
	_revalidate()

func _build_chunk_sequence(modules: Array) -> Array[String]:
	var chunks: Array[String] = ["Start"]
	visual_split_indices.clear()

	for module_index in range(modules.size()):
		var module: Dictionary = modules[module_index] as Dictionary
		if module["type"] == "corridor":
			chunks.append(str(module["kind"]))
		else:
			visual_split_indices[module_index] = chunks.size()
			_append_branch_chunks(chunks, module)

	chunks.append("Finish")
	return chunks

func _append_branch_chunks(chunks: Array[String], module: Dictionary) -> void:
	chunks.append("TripleSplit")
	var triple_length: int = int(module["triple_length"])
	for index in range(triple_length):
		if index == 0 and bool(module["use_triple_cross"]):
			chunks.append("CrossTriple")
		else:
			chunks.append("TripleStraight")

	var closing_dead_level: int = int(module["closing_dead_level"])
	var pair_chunk := "MiddleLowerStraight"
	var crossing_chunk := "CrossMiddleLower"
	var merge_chunk := "MergeMiddleLower"

	if closing_dead_level == LEVEL_UPPER:
		chunks.append("TripleCloseUpper")
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

	var pair_crossings: Array = module["pair_crossings"] as Array
	for use_crossing in pair_crossings:
		chunks.append(crossing_chunk if bool(use_crossing) else pair_chunk)

	chunks.append(merge_chunk)

func _apply_visual_split_indices() -> void:
	var branches: Array = level["branches"] as Array
	for branch_data in branches:
		var branch: Dictionary = branch_data as Dictionary
		var module_index: int = int(branch["module_index"])
		branch["split_index"] = int(visual_split_indices[module_index])

func _build_render_chunks(chunk_names: Array[String]) -> void:
	render_chunks.clear()
	for index in range(chunk_names.size()):
		render_chunks.append({
			"chunk_name": chunk_names[index],
			"world_position": SCREEN_ORIGIN + Vector2(float(index) * TILE_SIZE.x, 0.0),
		})

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
