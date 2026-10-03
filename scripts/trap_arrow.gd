extends Node2D

var direction := Vector2.LEFT
var speed := 420.0
var lifetime := 5.0


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var next_position := global_position + direction * speed * delta
	# Sweep the arrow tip so fast projectiles cannot skip the player or a wall.
	var tip := direction * 29.0
	var query := PhysicsRayQueryParameters2D.create(global_position + tip, next_position + tip, 3)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var body: Object = hit["collider"]
		if body is PlayerController and not body.is_dead:
			body.play_death()
		queue_free()
		return
	global_position = next_position
