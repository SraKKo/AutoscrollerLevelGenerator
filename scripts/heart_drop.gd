extends RigidBody2D

const DROP_CHANCE := 0.15


static func try_spawn(enemy: Node2D) -> void:
	if randf() >= DROP_CHANCE:
		return
	var scene: PackedScene = load("res://scenes/Interactables/Heart.tscn")
	var heart := scene.instantiate() as RigidBody2D
	heart.position = enemy.position + Vector2.UP * 14.0
	enemy.get_parent().add_child(heart)


func _on_pickup_body_entered(body: Node2D) -> void:
	if is_queued_for_deletion() or not body is PlayerController:
		return
	var heal_amount := maxi(1, roundi(body.max_health / 3.0))
	if body.heal(heal_amount):
		queue_free()
		SFX.play_effect(&"gem")
