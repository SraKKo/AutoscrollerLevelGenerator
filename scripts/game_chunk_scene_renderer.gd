class_name GameChunkSceneRenderer
extends ChunkRoomsRenderer

const CHUNK_SCENE_DIRECTORY := "res://scenes/Chunks"
const TILE_COLLISION_SETUP := preload("res://scripts/tile_collision_setup.gd")
const CHUNK_HALF_WIDTH := 1088.0
const SEAM_SAFE_WIDTH := 256.0
const SEAM_SAFE_COLUMNS := 8
const EDGE_TOP_ROW := -26
const EDGE_BOTTOM_ROW := 25
const SLOPE_ATLAS_COORDS: Array[Vector2i] = [Vector2i(1, 4), Vector2i(2, 4)]
const INVALID_SLOPE_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(1, -1),
	Vector2i(1, 1),
]

var layout_seed: int = 54321
var scene_variants: Dictionary = {}
var catalog_ready := false


func refresh_scene_variants(force: bool = false) -> void:
	if catalog_ready and not force:
		return
	scene_variants.clear()
	_scan_directory(CHUNK_SCENE_DIRECTORY)
	_validate_required_catalog()
	catalog_ready = true


func _scan_directory(directory: String) -> void:
	var entries := ResourceLoader.list_directory(directory)
	entries.sort()
	for entry in entries:
		var path := directory.path_join(entry)
		if entry.ends_with("/"):
			_scan_directory(path.trim_suffix("/"))
		elif entry.ends_with(".tscn"):
			if path.get_file().get_basename().begins_with("sample"):
				continue
			var chunk_type := directory.get_file()
			if chunk_type == "Crossings":
				chunk_type = _crossing_type(path)
			if chunk_type.is_empty():
				push_error("Brak metadata/chunk_type w skrzyżowaniu: %s" % path)
				continue
			if not ChunkPortContracts.RUNTIME_TYPES.has(chunk_type):
				continue
			var contract_error: String = _scene_contract_error(path, chunk_type)
			if not contract_error.is_empty():
				push_error("Odrzucono wariant %s: %s" % [path, contract_error])
				continue
			if not scene_variants.has(chunk_type):
				scene_variants[chunk_type] = []
			scene_variants[chunk_type].append(path)


func _scene_contract_error(path: String, chunk_type: String) -> String:
	var packed_scene: PackedScene = ResourceLoader.load(path) as PackedScene
	if packed_scene == null:
		return "nie mozna wczytac sceny"
	var chunk: Node2D = packed_scene.instantiate() as Node2D
	if chunk == null:
		return "korzen sceny nie jest Node2D"
	if chunk.has_meta("chunk_type") and str(chunk.get_meta("chunk_type")) != chunk_type:
		var declared_type: String = str(chunk.get_meta("chunk_type"))
		chunk.free()
		return "metadata podaje typ %s zamiast %s" % [declared_type, chunk_type]
	var ground: TileMapLayer = chunk.get_node_or_null("Ground") as TileMapLayer
	if ground == null:
		chunk.free()
		return "brak warstwy Ground"
	var edge_error: String = ChunkPortContracts.validate_ground_edges(ground, chunk_type)
	if not edge_error.is_empty():
		chunk.free()
		return edge_error
	var geometry_error: String = _seam_geometry_error(ground)
	if not geometry_error.is_empty():
		chunk.free()
		return geometry_error
	var slope_error: String = _slope_pattern_error(ground)
	if not slope_error.is_empty():
		chunk.free()
		return slope_error
	var seam_hazard: String = _first_hazard_in_seam_zone(chunk)
	chunk.free()
	if not seam_hazard.is_empty():
		return "%s znajduje sie w bezpiecznej strefie szwu" % seam_hazard
	return ""


func _seam_geometry_error(ground: TileMapLayer) -> String:
	for offset: int in range(1, SEAM_SAFE_COLUMNS):
		var left_column: int = ChunkPortContracts.LEFT_EDGE_COLUMN + offset
		if not _columns_share_occupancy(
			ground,
			ChunkPortContracts.LEFT_EDGE_COLUMN,
			left_column
		):
			return "geometria zmienia sie za blisko lewego szwu (kolumna %d)" % left_column

		var right_column: int = ChunkPortContracts.RIGHT_EDGE_COLUMN - offset
		if not _columns_share_occupancy(
			ground,
			ChunkPortContracts.RIGHT_EDGE_COLUMN,
			right_column
		):
			return "geometria zmienia sie za blisko prawego szwu (kolumna %d)" % right_column
	return ""


func _columns_share_occupancy(ground: TileMapLayer, first: int, second: int) -> bool:
	for row: int in range(EDGE_TOP_ROW, EDGE_BOTTOM_ROW + 1):
		var first_used: bool = ground.get_cell_source_id(Vector2i(first, row)) != -1
		var second_used: bool = ground.get_cell_source_id(Vector2i(second, row)) != -1
		if first_used != second_used:
			return false
	return true


func _slope_pattern_error(ground: TileMapLayer) -> String:
	for cell: Vector2i in ground.get_used_cells():
		if not _is_slope_cell(ground, cell):
			continue
		for offset: Vector2i in INVALID_SLOPE_OFFSETS:
			var neighbor := cell + offset
			if not _same_slope_variant(ground, cell, neighbor):
				continue
			if offset.x == 0:
				return "slope powtorzony pionowo przy %s" % cell
			return "brak pelnego kafla miedzy slope'ami przy %s" % cell
	return ""


func _is_slope_cell(ground: TileMapLayer, cell: Vector2i) -> bool:
	if ground.get_cell_source_id(cell) == -1:
		return false
	var atlas_coords: Vector2i = ground.get_cell_atlas_coords(cell)
	return SLOPE_ATLAS_COORDS.has(atlas_coords)


func _same_slope_variant(
	ground: TileMapLayer,
	first: Vector2i,
	second: Vector2i
) -> bool:
	if not _is_slope_cell(ground, first) or not _is_slope_cell(ground, second):
		return false
	return (
		ground.get_cell_source_id(first) == ground.get_cell_source_id(second)
		and ground.get_cell_atlas_coords(first) == ground.get_cell_atlas_coords(second)
		and ground.get_cell_alternative_tile(first)
		== ground.get_cell_alternative_tile(second)
	)


func _first_hazard_in_seam_zone(chunk: Node2D) -> String:
	var seam_limit := CHUNK_HALF_WIDTH - SEAM_SAFE_WIDTH
	for node: Node in chunk.find_children("*", "Node2D", true, false):
		var node_2d := node as Node2D
		if node_2d == null:
			continue
		var scene_path: String = node.scene_file_path.to_lower()
		var is_hazard := "/traps/" in scene_path or "/enemies/" in scene_path
		if not is_hazard:
			continue
		var relative_x: float = chunk.to_local(node_2d.global_position).x
		if absf(relative_x) > seam_limit:
			return "%s@x=%.0f" % [node.name, relative_x]
	return ""


func _validate_required_catalog() -> void:
	for chunk_type: String in ChunkPortContracts.RUNTIME_TYPES:
		var candidates: Array = scene_variants.get(chunk_type, [])
		var has_finished := false
		for path: String in candidates:
			if not path.get_file().get_basename().begins_with("sample"):
				has_finished = true
				break
		if not has_finished:
			push_error("Brak poprawnego gotowego wariantu chunka: %s" % chunk_type)


func _crossing_type(path: String) -> String:
	var scene := ResourceLoader.load(path) as PackedScene
	if scene == null:
		return ""
	var state := scene.get_state()
	for property_index in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, property_index) == "metadata/chunk_type":
			return str(state.get_node_property_value(0, property_index))
	return ""


func _choose_scene(
	chunk_type: String,
	rng: RandomNumberGenerator,
	avoid_path: String = ""
) -> String:
	var candidates: Array = scene_variants.get(chunk_type, [])
	var finished: Array[String] = []
	for path: String in candidates:
		if not path.get_file().get_basename().begins_with("sample"):
			finished.append(path)
	if not finished.is_empty():
		var selection_pool: Array[String] = finished
		if finished.size() > 1 and finished.has(avoid_path):
			selection_pool = finished.duplicate()
			selection_pool.erase(avoid_path)
		return selection_pool[rng.randi_range(0, selection_pool.size() - 1)]
	if not candidates.is_empty():
		return str(candidates[rng.randi_range(0, candidates.size() - 1)])
	return ""


func rebuild(render_chunks: Array) -> Array[Vector2]:
	_clear_chunk_instances()
	refresh_scene_variants()
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var room_positions: Array[Vector2] = []
	var last_variant_by_type: Dictionary = {}
	for chunk_data in render_chunks:
		var room: Dictionary = chunk_data as Dictionary
		var chunk_name: String = str(room["chunk_name"])
		var previous_variant: String = str(last_variant_by_type.get(chunk_name, ""))
		var scene_path := _choose_scene(chunk_name, rng, previous_variant)
		if scene_path.is_empty():
			push_error("Brak wariantów chunka: %s" % chunk_name)
			continue
		last_variant_by_type[chunk_name] = scene_path
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
