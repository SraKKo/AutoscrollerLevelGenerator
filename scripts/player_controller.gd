class_name PlayerController
extends CharacterBody2D

const ATTACK_ANIMATIONS: Array[StringName] = [&"attack_1", &"attack_2", &"attack_3"]

@export_range(50.0, 1000.0, 10.0) var move_speed := 360.0
@export_range(100.0, 3000.0, 50.0) var ground_acceleration := 1800.0
@export_range(100.0, 3000.0, 50.0) var air_acceleration := 900.0
@export_range(100.0, 1500.0, 10.0) var jump_velocity := 620.0
@export_range(100.0, 1500.0, 10.0) var air_sweep_velocity := 360.0
@export_range(100.0, 1500.0, 10.0) var slide_speed := 620.0
@export_range(100.0, 3000.0, 50.0) var slide_deceleration := 700.0
@export_range(0.1, 2.0, 0.05) var combo_reset_delay := 0.75
@export_range(100.0, 2000.0, 50.0) var maximum_fall_speed := 1200.0
@export_range(0.0, 200.0, 1.0) var screen_margin := 56.0
@export var camera_path: NodePath

var spawn_position := Vector2.ZERO
var action_locked := false
var is_dead := false
var air_sweep_available := true
var is_sliding := false
var attack_combo_step := 0
var attack_queued := false
var combo_reset_timer := 0.0
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
	_update_combo_timer(delta)

	var direction: float = Input.get_axis("ui_left", "ui_right")
	var wasd_direction: float = (
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	)
	if not is_zero_approx(wasd_direction):
		direction = wasd_direction

	var acceleration: float = ground_acceleration if is_on_floor() else air_acceleration
	if is_sliding:
		velocity.x = move_toward(velocity.x, 0.0, slide_deceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * delta)
	_apply_gravity(delta)
	_handle_jump_input()

	move_and_slide()
	if is_on_floor():
		air_sweep_available = true
	_keep_inside_camera()
	_update_facing()
	_update_animation()
	_handle_action_input()


func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	is_dead = false
	action_locked = false
	air_sweep_available = true
	is_sliding = false
	attack_combo_step = 0
	attack_queued = false
	combo_reset_timer = 0.0
	animated_sprite.play(&"idle")


func play_hurt() -> void:
	_play_action(&"hurt")


func play_death() -> void:
	is_dead = true
	action_locked = true
	velocity = Vector2.ZERO
	_play_if_available(&"death", &"idle")


func _handle_action_input() -> void:
	var attack_pressed := Input.is_action_just_pressed("attack")
	if attack_pressed and action_locked:
		if _is_attack_animation(animated_sprite.animation):
			attack_queued = true
		return
	if action_locked:
		return
	if Input.is_action_just_pressed("slide") and is_on_floor():
		_start_slide()
	elif attack_pressed:
		_play_next_attack()


func _play_next_attack() -> void:
	if is_dead:
		return
	var animation_name: StringName = ATTACK_ANIMATIONS[attack_combo_step]
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	action_locked = true
	attack_combo_step = (attack_combo_step + 1) % ATTACK_ANIMATIONS.size()
	combo_reset_timer = combo_reset_delay
	animated_sprite.play(animation_name)


func _update_combo_timer(delta: float) -> void:
	if action_locked or attack_combo_step == 0:
		return
	combo_reset_timer = maxf(combo_reset_timer - delta, 0.0)
	if is_zero_approx(combo_reset_timer):
		attack_combo_step = 0


func _is_attack_animation(animation_name: StringName) -> bool:
	return ATTACK_ANIMATIONS.has(animation_name)


func _start_slide() -> void:
	var slide_direction := -1.0 if animated_sprite.flip_h else 1.0
	if not is_zero_approx(velocity.x):
		slide_direction = signf(velocity.x)
	is_sliding = true
	velocity.x = slide_direction * slide_speed
	_play_action(&"slide")


func _handle_jump_input() -> void:
	if not Input.is_action_just_pressed("ui_accept") or action_locked:
		return
	if is_on_floor():
		velocity.y = -jump_velocity
		animated_sprite.play(&"jump")
	elif air_sweep_available:
		air_sweep_available = false
		velocity.y = -air_sweep_velocity
		_play_action(&"air_sweep")


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
	if _is_attack_animation(animated_sprite.animation) and attack_queued:
		attack_queued = false
		_play_next_attack()
		return
	if animated_sprite.animation == &"slide":
		is_sliding = false
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
