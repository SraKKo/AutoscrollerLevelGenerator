extends Area2D

var direction := Vector2.LEFT
var speed := 420.0
var lifetime := 5.0
var is_destroyed := false


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
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
			body.take_damage(1, global_position)
		queue_free()
		return
	global_position = next_position


func receive_hit() -> bool:
	if is_destroyed:
		return false
	is_destroyed = true
	collision_layer = 0
	set_physics_process(false)
	queue_free()
	return true
