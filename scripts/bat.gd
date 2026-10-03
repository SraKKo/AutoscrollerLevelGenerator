extends Area2D

var is_dead := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.play(&"idle")


# Returns true only for the hit that kills this enemy.
func receive_hit() -> bool:
	if is_dead:
		return false
	is_dead = true
	set_deferred("collision_layer", 0)
	animated_sprite.play(&"death")
	return true


func _on_animation_finished() -> void:
	if is_dead and animated_sprite.animation == &"death":
		queue_free()
