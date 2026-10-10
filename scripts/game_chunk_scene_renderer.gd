class_name GameChunkSceneRenderer
extends ChunkRoomsRenderer

const CHUNK_SCENE_DIRECTORY := "res://scenes/Chunks"
const TILE_COLLISION_SETUP := preload("res://scripts/tile_collision_setup.gd")

var layout_seed: int = 54321
var scene_variants: Dictionary = {}


func refresh_scene_variants() -> void:
	scene_variants.clear()
	_scan_directory(CHUNK_SCENE_DIRECTORY)


func _scan_directory(directory: String) -> void:
	var entries := ResourceLoader.list_directory(directory)
	entries.sort()
	for entry in entries:
		var path := directory.path_join(entry)
		if entry.ends_with("/"):
			_scan_directory(path.trim_suffix("/"))
		elif entry.ends_with(".tscn"):
			var chunk_type := directory.get_file()
			if chunk_type == "Crossings":
				chunk_type = _crossing_type(path)
			if chunk_type.is_empty():
				push_error("Brak metadata/chunk_type w skrzyżowaniu: %s" % path)
				continue
			if not scene_variants.has(chunk_type):
				scene_variants[chunk_type] = []
			scene_variants[chunk_type].append(path)


func _crossing_type(path: String) -> String:
	var scene := ResourceLoader.load(path) as PackedScene
	if scene == null:
		return ""
	var state := scene.get_state()
	for property_index in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, property_index) == "metadata/chunk_type":
			return str(state.get_node_property_value(0, property_index))
	return ""


func _choose_scene(chunk_type: String, rng: RandomNumberGenerator) -> String:
	var candidates: Array = scene_variants.get(chunk_type, [])
	var finished: Array[String] = []
	for path: String in candidates:
		if not path.get_file().get_basename().begins_with("sample"):
			finished.append(path)
	if not finished.is_empty():
		return finished[rng.randi_range(0, finished.size() - 1)]
	if not candidates.is_empty():
		return str(candidates[rng.randi_range(0, candidates.size() - 1)])
	return ""


func rebuild(render_chunks: Array) -> Array[Vector2]:
	_clear_chunk_instances()
	refresh_scene_variants()
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var room_positions: Array[Vector2] = []
	for chunk_data in render_chunks:
		var room: Dictionary = chunk_data as Dictionary
		var chunk_name: String = str(room["chunk_name"])
		var scene_path := _choose_scene(chunk_name, rng)
		if scene_path.is_empty():
			push_error("Brak wariantów chunka: %s" % chunk_name)
			continue
		var packed_scene: PackedScene = ResourceLoader.load(scene_path) as PackedScene
		if packed_scene == null:
			push_error("Brak sceny chunka: %s" % scene_path)
			continue
		var chunk := packed_scene.instantiate() as Node2D
		chunk.name = "Chunk_%s" % chunk_name
		chunk.position = room["world_position"] as Vector2
		var ground: TileMapLayer = chunk.get_node_or_null("Ground") as TileMapLayer
		if ground != null:
			TILE_COLLISION_SETUP.ensure_for(ground)
		var guide: Sprite2D = chunk.get_node_or_null(chunk_name) as Sprite2D
		if guide != null:
			guide.visible = false
		add_child(chunk)
		room_positions.append(chunk.position)
	return room_positions


func _clear_chunk_instances() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
