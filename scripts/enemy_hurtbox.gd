extends Area2D


func receive_hit() -> bool:
	return get_parent().receive_hit()
