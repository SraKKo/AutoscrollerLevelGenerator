class_name ChunkRouteSigns
extends Node2D

const GOOD_ROUTE_TEXTURE := preload("res://Assets/Misc/y.png")
const BAD_ROUTE_TEXTURE := preload("res://Assets/Misc/n.png")
const MAYBE_ROUTE_TEXTURE := preload("res://Assets/Misc/maybe.png")
const LEVEL_MIDDLE := 408
const SIGN_SCALE := Vector2(0.38, 0.38)
const SIGN_X_OFFSET := 380.0

func update_signs(level: Dictionary, render_chunks: Array) -> void:
	_clear_signs()
	if level.is_empty():
		return

	var validation: Dictionary = level["validation"] as Dictionary
	var path: Array = validation["path"] as Array
	var path_lookup: Dictionary = {}
	for path_id in path:
		path_lookup[int(path_id)] = true

	var branches: Array = level["branches"] as Array
	var graph: Dictionary = level["graph"] as Dictionary
	var goal_id: int = int(level["goal_id"])
	for branch_data in branches:
		var branch: Dictionary = branch_data as Dictionary
		var split_index: int = int(branch["split_index"])
		var split_chunk: Dictionary = render_chunks[split_index] as Dictionary
		var split_position: Vector2 = split_chunk["world_position"] as Vector2
		var routes: Array = branch["routes"] as Array

		for route_data in routes:
			var route: Dictionary = route_data as Dictionary
			var route_id: int = int(route["route_id"])
			var route_level: int = int(route["level"])
			if path_lookup.has(route_id):
				_add_sign(GOOD_ROUTE_TEXTURE, split_position, route_level, "Good")
			elif _can_reach_goal(graph, route_id, goal_id):
				_add_sign(MAYBE_ROUTE_TEXTURE, split_position, route_level, "Maybe")
			else:
				_add_sign(BAD_ROUTE_TEXTURE, split_position, route_level, "Bad")

func _can_reach_goal(graph: Dictionary, route_id: int, goal_id: int) -> bool:
	var result: Dictionary = PlatformGraphValidator.validate_path(
		graph,
		route_id,
		goal_id,
		PlatformGraphValidator.METHOD_BFS
	)
	return bool(result["playable"])

func _clear_signs() -> void:
	for child in get_children():
		child.queue_free()

func _add_sign(texture: Texture2D, split_position: Vector2, route_level: int, sign_name: String) -> void:
	var sign := Sprite2D.new()
	sign.name = "%sRoute" % sign_name
	sign.texture = texture
	sign.position = split_position + Vector2(SIGN_X_OFFSET, float(route_level - LEVEL_MIDDLE))
	sign.scale = SIGN_SCALE
	sign.z_index = 10
	add_child(sign)
