class_name PlayerController
extends CharacterBody2D

@export_range(50.0, 1000.0, 10.0) var move_speed := 360.0
@export_range(100.0, 3000.0, 50.0) var ground_acceleration := 1800.0
@export_range(100.0, 3000.0, 50.0) var air_acceleration := 900.0
@export_range(100.0, 1500.0, 10.0) var jump_velocity := 620.0
@export_range(100.0, 2000.0, 50.0) var maximum_fall_speed := 1200.0
@export_range(0.0, 200.0, 1.0) var screen_margin := 56.0
@export var camera_path: NodePath

var spawn_position := Vector2.ZERO
var action_locked := false
var is_dead := false
var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))

@onready var scrolling_camera: Camera2D = get_node(camera_path) as Camera2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	spawn_position = global_position
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		_apply_gravity(delta)
		move_and_slide()
		return

	var direction: float = Input.get_axis("ui_left", "ui_right")
	var wasd_direction: float = (
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	)
	if not is_zero_approx(wasd_direction):
		direction = wasd_direction

	var acceleration: float = ground_acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * delta)
	_apply_gravity(delta)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not action_locked:
		velocity.y = -jump_velocity
		animated_sprite.play(&"jump")

	move_and_slide()
	_keep_inside_camera()
	_update_facing()
	_update_animation()
	_handle_action_input()


func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	is_dead = false
	action_locked = false
	animated_sprite.play(&"idle")


func play_hurt() -> void:
	_play_action(&"hurt")


func play_death() -> void:
	is_dead = true
	action_locked = true
	velocity = Vector2.ZERO
	_play_if_available(&"death", &"idle")


func _handle_action_input() -> void:
	if action_locked:
		return
	if Input.is_key_pressed(KEY_Q):
		_play_action(&"attack_1")
	elif Input.is_key_pressed(KEY_E):
		_play_action(&"attack_2")
	elif Input.is_key_pressed(KEY_F):
		_play_action(&"attack_3")


func _play_action(animation_name: StringName) -> void:
	if action_locked or is_dead:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	action_locked = true
	animated_sprite.play(animation_name)


func _play_if_available(animation_name: StringName, fallback: StringName) -> void:
	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	else:
		animated_sprite.play(fallback)


func _update_facing() -> void:
	if not is_zero_approx(velocity.x):
		animated_sprite.flip_h = velocity.x < 0.0


func _update_animation() -> void:
	if action_locked:
		return
	var next_animation: StringName
	if not is_on_floor():
		next_animation = &"jump"
	elif absf(velocity.x) > 1.0:
		next_animation = &"run"
	else:
		next_animation = &"idle"
	if animated_sprite.animation != next_animation:
		animated_sprite.play(next_animation)


func _on_animation_finished() -> void:
	if animated_sprite.animation == &"death":
		return
	if animated_sprite.animation == &"jump" and not is_on_floor():
		return
	action_locked = false
	_update_animation()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, maximum_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _keep_inside_camera() -> void:
	if not is_instance_valid(scrolling_camera):
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var visible_half_size: Vector2 = Vector2(
		viewport_size.x / scrolling_camera.zoom.x,
		viewport_size.y / scrolling_camera.zoom.y
	) * 0.5
	var camera_center: Vector2 = scrolling_camera.get_screen_center_position()
	var minimum: Vector2 = camera_center - visible_half_size + Vector2.ONE * screen_margin
	var maximum: Vector2 = camera_center + visible_half_size - Vector2.ONE * screen_margin
	global_position = global_position.clamp(minimum, maximum)
