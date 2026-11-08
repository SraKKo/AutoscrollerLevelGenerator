extends Area2D

signal stage_entered(player: PlayerController)

var activated := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Visuals/PortalSprite.play(&"active")


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
