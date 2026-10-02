extends Camera2D

@export var scroll_speed: float = 220  
@export var player: Node2D             

func _process(delta: float) -> void:
	
	global_position.x += scroll_speed * delta
	
	if player and player.global_position.x < global_position.x - 500:
		player.global_position.x = global_position.x - 500
