extends Area2D

@export_range(0.1, 3.0, 0.05) var fuse_time := 0.8
@export_range(0.1, 1.0, 0.05) var explosion_time := 0.2

var exploding := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var fuse: Timer = $FuseTimer
@onready var cleanup: Timer = $CleanupTimer
@onready var explosion: AnimatedSprite2D = $Explosion


func _ready() -> void:
	fuse.timeout.connect(_explode)
	cleanup.timeout.connect(func() -> void: exploding = false)
	explosion.animation_finished.connect(queue_free)
	fuse.start(fuse_time)
	var pulse := create_tween().set_loops()
	pulse.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.15)
	pulse.tween_property(sprite, "scale", Vector2.ONE, 0.15)


func _physics_process(_delta: float) -> void:
	if exploding:
		for body in get_overlapping_bodies():
			if body is PlayerController and not body.is_dead:
				body.take_damage(1, global_position)


func _explode() -> void:
	if exploding:
		return
	SFX.play_effect(&"fireball", self)
	exploding = true
	sprite.hide()
	explosion.show()
	explosion.play(&"explode")
	cleanup.start(explosion_time)
