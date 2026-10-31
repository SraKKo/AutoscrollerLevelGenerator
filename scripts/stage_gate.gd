extends Area2D

signal stage_entered(player: PlayerController)

@export var gate_texture: Texture2D

var activated := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if gate_texture != null:
		$Visuals/Sprite2D.texture = gate_texture
		$Visuals/Sprite2D.show()
		$Visuals/Placeholder.hide()
	else:
		var pulse := create_tween().set_loops()
		pulse.tween_property($Visuals/Placeholder/Portal, "modulate:a", 0.45, 0.7)
		pulse.tween_property($Visuals/Placeholder/Portal, "modulate:a", 1.0, 0.7)


func _on_body_entered(body: Node2D) -> void:
	if activated or not body is PlayerController or body.is_dead:
		return
	# A freshly generated gate can receive an old physics overlap while
	# the player is already back at spawn. Ignore those stale events.
	var gate_bounds: Rect2 = $CollisionShape2D.global_transform * $CollisionShape2D.shape.get_rect()
	var player_bounds: Rect2 = body.body_shape.global_transform * body.body_shape.shape.get_rect()
	if not gate_bounds.grow(2.0).intersects(player_bounds):
		return
	activated = true
	set_deferred("monitoring", false)
	stage_entered.emit(body)
