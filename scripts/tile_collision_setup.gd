class_name TileCollisionSetup
extends RefCounted

const READY_META := &"ground_collision_ready"
const TILE_LAYER_SCENE: PackedScene = preload("res://scenes/tile_map_layer.tscn")


static func ensure_for(ground: TileMapLayer) -> void:
	var tile_set: TileSet = ground.tile_set
	if tile_set == null or tile_set.has_meta(READY_META):
		return

	var template_layer: TileMapLayer = TILE_LAYER_SCENE.instantiate() as TileMapLayer
	var template_set: TileSet = template_layer.tile_set
	_copy_physics_layer(template_set, tile_set)

	var configured_tiles: Dictionary = {}
	for cell: Vector2i in ground.get_used_cells():
		var source_id: int = ground.get_cell_source_id(cell)
		var atlas_coordinates: Vector2i = ground.get_cell_atlas_coords(cell)
		var tile_key := Vector3i(source_id, atlas_coordinates.x, atlas_coordinates.y)
		if configured_tiles.has(tile_key):
			continue
		configured_tiles[tile_key] = true

		var target_source: TileSetAtlasSource = tile_set.get_source(source_id) as TileSetAtlasSource
		var template_source: TileSetAtlasSource = template_set.get_source(source_id) as TileSetAtlasSource
		if target_source == null or template_source == null:
			continue
		var target_data: TileData = target_source.get_tile_data(atlas_coordinates, 0)
		var template_data: TileData = template_source.get_tile_data(atlas_coordinates, 0)
		if target_data == null or template_data == null:
			continue
		_copy_tile_polygons(template_data, target_data)

	tile_set.set_meta(READY_META, true)
	template_layer.free()


static func _copy_physics_layer(source: TileSet, target: TileSet) -> void:
	if source.get_physics_layers_count() == 0:
		return
	if target.get_physics_layers_count() == 0:
		target.add_physics_layer()
	target.set_physics_layer_collision_layer(0, source.get_physics_layer_collision_layer(0))
	target.set_physics_layer_collision_mask(0, source.get_physics_layer_collision_mask(0))


static func _copy_tile_polygons(source: TileData, target: TileData) -> void:
	var polygon_count: int = source.get_collision_polygons_count(0)
	target.set_collision_polygons_count(0, polygon_count)
	for polygon_index: int in range(polygon_count):
		var points: PackedVector2Array = source.get_collision_polygon_points(0, polygon_index)
		target.set_collision_polygon_points(0, polygon_index, points)
		target.set_collision_polygon_one_way(
			0,
			polygon_index,
			source.is_collision_polygon_one_way(0, polygon_index)
		)
		target.set_collision_polygon_one_way_margin(
			0,
			polygon_index,
			source.get_collision_polygon_one_way_margin(0, polygon_index)
		)
