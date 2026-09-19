class_name ChunkGraphDebug
extends Node2D

@export var show_connections := false:
	set(value):
		show_connections = value
		queue_redraw()

var render_chunks: Array = []

func update_chunks(chunks: Array) -> void:
	render_chunks = chunks.duplicate(true)
	queue_redraw()

func _draw() -> void:
	if not show_connections:
		return

	for index in range(render_chunks.size() - 1):
		var from_chunk: Dictionary = render_chunks[index] as Dictionary
		var to_chunk: Dictionary = render_chunks[index + 1] as Dictionary
		var from_position: Vector2 = from_chunk["world_position"] as Vector2
		var to_position: Vector2 = to_chunk["world_position"] as Vector2
		draw_line(from_position, to_position, Color("#22c55e"), 7.0)
