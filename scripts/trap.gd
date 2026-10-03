extends Area2D

enum Kind { SAW, CEILING, ARROW }

const ARROW_SCENE := preload("res://scenes/Traps/Arrow.tscn")
const CEILING_HEIGHTS := [7.0, 59.0, 59.0, 59.0, 55.0, 47.0, 39.0, 31.0, 23.0, 15.0, 7.0, 7.0, 7.0, 7.0]

@export var kind: Kind = Kind.SAW
@export_range(0.1, 3.0, 0.1) var animation_speed := 1.0
@export_range(50.0, 1200.0, 10.0) var arrow_speed := 420.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	sprite.speed_scale = animation_speed
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play(&"activate" if sprite.sprite_frames.has_animation(&"activate") else &"active")
	_on_frame_changed()


func _physics_process(_delta: float) -> void:
	if kind == Kind.ARROW or sprite.animation != &"active":
		return
	# Query the current head position rather than the previous frame's overlaps.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = hitbox.shape
	query.transform = hitbox.global_transform
	query.collision_mask = collision_mask
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var body: Object = hit["collider"]
		if body is PlayerController and not body.is_dead:
			body.play_death()


func _on_frame_changed() -> void:
	if sprite.animation != &"active":
		return
	if kind == Kind.CEILING:
		hitbox.position.y = CEILING_HEIGHTS[sprite.frame]
	elif kind == Kind.ARROW and sprite.frame == 8:
		var arrow := ARROW_SCENE.instantiate()
		get_parent().add_child(arrow)
		arrow.global_position = to_global(Vector2(24.0, 21.0))
		arrow.direction = -global_transform.x.normalized()
		arrow.speed = arrow_speed
		arrow.rotation = arrow.direction.angle() - PI


func _on_animation_finished() -> void:
	if sprite.animation == &"activate":
		sprite.play(&"active")
