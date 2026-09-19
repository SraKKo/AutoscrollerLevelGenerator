class_name ProceduralLevelGenerator
extends RefCounted

const DEFAULT_JUMP_RULES := {
	"max_jump_distance": 170.0,
	"max_jump_height": 130.0,
	"max_drop_height": 130.0,
	"angle_tolerance": 6.0,
	"flat_tolerance": 6.0,
}

const PLATFORM_HEIGHT := 24.0
const MAIN_STEP := 120.0
const MIN_CENTER_Y := 230.0
const MAX_CENTER_Y := 610.0

var rng := RandomNumberGenerator.new()

func generate(seed_value: int, platform_count: int = 14, max_attempts: int = 80) -> Dictionary:
	rng.seed = seed_value
	var main_path_count: int = int(max(5, platform_count))

	for attempt in range(max_attempts):
		var platforms: Array = _generate_platforms(main_path_count)
		var graph: Dictionary = PlatformGraphValidator.build_reachability_graph(platforms, DEFAULT_JUMP_RULES)
		var validation: Dictionary = PlatformGraphValidator.validate_path(
			graph,
			int(platforms.front()["id"]),
			main_path_count - 1,
			PlatformGraphValidator.METHOD_BFS
		)

		if validation["playable"]:
			return _level_result(seed_value, attempt + 1, platforms, graph, validation, 0, main_path_count - 1)

	return _fallback_level(seed_value)

func _generate_platforms(platform_count: int) -> Array:
	var platforms: Array = []
	var center: Vector2 = Vector2(170.0, 500.0)
	var main_path_count: int = int(max(5, platform_count))

	for i in range(main_path_count):
		var width: float = rng.randf_range(85.0, 145.0)
		if i == 0:
			width = 180.0
		elif i == main_path_count - 1:
			width = 160.0

		platforms.append(_create_platform(i, center, width, _platform_type(i, main_path_count)))

		if i < main_path_count - 1:
			center += _next_step(center)

	_add_dead_ends(platforms, main_path_count)

	return platforms

func _fallback_level(seed_value: int) -> Dictionary:
	var platforms: Array = []
	var center: Vector2 = Vector2(170.0, 500.0)

	for i in range(9):
		platforms.append(_create_platform(i, center, 145.0, _platform_type(i, 9)))
		if i % 3 == 0:
			center += Vector2(MAIN_STEP, 0.0)
		else:
			center += Vector2(MAIN_STEP, -MAIN_STEP if i % 2 == 0 else MAIN_STEP)

	var graph: Dictionary = PlatformGraphValidator.build_reachability_graph(platforms, DEFAULT_JUMP_RULES)
	var validation: Dictionary = PlatformGraphValidator.validate_path(graph, 0, 8)
	return _level_result(seed_value, -1, platforms, graph, validation, 0, 8)

func _add_dead_ends(platforms: Array, main_path_count: int) -> void:
	var next_id: int = main_path_count
	var branch_count: int = int(max(2.0, float(main_path_count) / 3.0))
	var used_sources: Dictionary = {}

	for _branch_index in range(branch_count):
		var source_index: int = rng.randi_range(1, main_path_count - 3)
		if used_sources.has(source_index):
			continue

		used_sources[source_index] = true
		var source_platform: Dictionary = platforms[source_index] as Dictionary
		var next_main_platform: Dictionary = platforms[source_index + 1] as Dictionary
		var source_center: Vector2 = source_platform["center"] as Vector2
		var next_main_center: Vector2 = next_main_platform["center"] as Vector2
		var branch_step: Vector2 = _dead_end_step(source_center, next_main_center)
		var branch_center: Vector2 = source_center + branch_step

		if branch_center.y < MIN_CENTER_Y or branch_center.y > MAX_CENTER_Y:
			branch_step.y *= -1.0
			branch_center = source_center + branch_step

		if _overlaps_existing_center(platforms, branch_center):
			continue

		platforms.append(_create_platform(next_id, branch_center, 110.0, "dead_end"))
		next_id += 1

		if rng.randf() < 0.45:
			var second_step: Vector2 = _next_step(branch_center)
			var second_center: Vector2 = branch_center + second_step
			if second_center.y >= MIN_CENTER_Y and second_center.y <= MAX_CENTER_Y and not _overlaps_existing_center(platforms, second_center):
				platforms.append(_create_platform(next_id, second_center, 95.0, "dead_end"))
				next_id += 1

func _create_platform(id: int, center: Vector2, width: float, type: String) -> Dictionary:
	var size: Vector2 = Vector2(width, PLATFORM_HEIGHT)
	return {
		"id": id,
		"position": center - size * 0.5,
		"size": size,
		"center": center,
		"type": type,
	}

func _next_step(center: Vector2) -> Vector2:
	var direction: int = _next_vertical_direction(center)
	if rng.randf() < 0.35:
		return Vector2(MAIN_STEP, 0.0)
	return Vector2(MAIN_STEP, MAIN_STEP * direction)

func _dead_end_step(source_center: Vector2, next_main_center: Vector2) -> Vector2:
	var main_delta: Vector2 = next_main_center - source_center
	if abs(main_delta.y) <= float(DEFAULT_JUMP_RULES["flat_tolerance"]):
		return Vector2(MAIN_STEP, MAIN_STEP * _next_vertical_direction(source_center))

	return Vector2(MAIN_STEP, -main_delta.y)

func _next_vertical_direction(center: Vector2) -> int:
	if center.y <= MIN_CENTER_Y + MAIN_STEP:
		return 1
	if center.y >= MAX_CENTER_Y - MAIN_STEP:
		return -1
	return -1 if rng.randf() < 0.5 else 1

func _overlaps_existing_center(platforms: Array, center: Vector2) -> bool:
	for platform in platforms:
		var platform_data: Dictionary = platform as Dictionary
		var platform_center: Vector2 = platform_data["center"] as Vector2
		if platform_center.distance_to(center) < MAIN_STEP * 0.5:
			return true
	return false

func _level_result(seed_value: int, attempts: int, platforms: Array, graph: Dictionary, validation: Dictionary, start_id: int, goal_id: int) -> Dictionary:
	return {
		"seed": seed_value,
		"attempts": attempts,
		"platforms": platforms,
		"graph": graph,
		"validation": validation,
		"jump_rules": DEFAULT_JUMP_RULES,
		"start_id": start_id,
		"goal_id": goal_id,
	}

func _platform_type(index: int, platform_count: int) -> String:
	if index == 0:
		return "start"
	if index == platform_count - 1:
		return "goal"
	return "normal"
