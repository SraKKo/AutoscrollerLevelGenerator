extends Area2D


func receive_hit(source_position: Vector2 = Vector2.INF) -> bool:
	return get_parent().receive_hit(source_position)
