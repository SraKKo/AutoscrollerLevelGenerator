class_name GameChunkSceneRenderer
extends ChunkRoomsRenderer

const CHUNK_SCENE_DIRECTORY := "res://scenes/Chunks"
const TILE_COLLISION_SETUP := preload("res://scripts/tile_collision_setup.gd")


func rebuild(render_chunks: Array) -> Array[Vector2]:
	_clear_chunk_instances()
	var room_positions: Array[Vector2] = []
	for chunk_data in render_chunks:
		var room: Dictionary = chunk_data as Dictionary
		var chunk_name: String = str(room["chunk_name"])
		var scene_path := "%s/%s.tscn" % [CHUNK_SCENE_DIRECTORY, chunk_name]
		var packed_scene: PackedScene = load(scene_path) as PackedScene
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
