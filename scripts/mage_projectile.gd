extends Area2D

@export_range(0.1, 3.0, 0.05) var fuse_time := 0.8
@export_range(0.1, 1.0, 0.05) var explosion_time := 0.2

var is_destroyed := false
var exploding := false

@onready var warning: Polygon2D = $WarningCircle
@onready var sprite: Sprite2D = $Sprite2D
@onready var fuse: Timer = $FuseTimer
@onready var cleanup: Timer = $CleanupTimer


func _ready() -> void:
	fuse.timeout.connect(_explode)
	cleanup.timeout.connect(queue_free)
	fuse.start(fuse_time)
	var pulse := create_tween().set_loops()
	pulse.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.15)
	pulse.tween_property(sprite, "scale", Vector2.ONE, 0.15)


func _physics_process(_delta: float) -> void:
	if exploding and not is_destroyed:
		for body in get_overlapping_bodies():
			if body is PlayerController and not body.is_dead:
				body.take_damage(1, global_position)


func _explode() -> void:
	if is_destroyed:
		return
	exploding = true
	sprite.hide()
	warning.color = Color(1.0, 0.45, 0.1, 0.85)
	cleanup.start(explosion_time)


func receive_hit() -> bool:
	if is_destroyed or exploding:
		return false
	is_destroyed = true
	fuse.stop()
	set_deferred("collision_layer", 0)
	hide()
	queue_free()
	return true
