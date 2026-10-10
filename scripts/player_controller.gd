class_name PlayerController
extends CharacterBody2D

const ATTACK_ANIMATIONS: Array[StringName] = [&"attack_1", &"attack_2", &"attack_3"]

signal health_changed(current_health: int, maximum_health: int)
signal coins_changed(total_coins: int)

@export_range(1, 10, 1) var max_health := 3
@export_range(0.1, 3.0, 0.05) var invulnerability_duration := 1.0
@export var knockback_speed := 140.0
@export var knockback_lift := 100.0

@export_range(50.0, 1000.0, 10.0) var move_speed := 360.0
@export_range(100.0, 3000.0, 50.0) var ground_acceleration := 1800.0
@export_range(100.0, 3000.0, 50.0) var air_acceleration := 900.0
@export_range(100.0, 1500.0, 10.0) var jump_velocity := 620.0
@export_range(100.0, 1000.0, 10.0) var wall_jump_push_speed := 360.0
@export_range(0.0, 0.5, 0.01) var wall_jump_control_delay := 0.15
@export_range(0.0, 0.5, 0.01) var coyote_time := 0.12
@export_range(100.0, 1500.0, 10.0) var air_sweep_velocity := 360.0
@export_range(100.0, 1500.0, 10.0) var slide_speed := 620.0
@export_range(100.0, 3000.0, 50.0) var slide_deceleration := 700.0
@export_range(0.1, 2.0, 0.05) var combo_reset_delay := 0.75
@export_range(100.0, 2000.0, 50.0) var maximum_fall_speed := 1200.0
@export_range(0.0, 200.0, 1.0) var screen_margin := 56.0
@export var camera_path: NodePath

var spawn_position := Vector2.ZERO
var health := 3
var coins := 0
var action_locked := false
var is_dead := false
var air_sweep_available := true
var is_sliding := false
var attack_combo_step := 0
var attack_queued := false
var attack_targets: Dictionary = {}
var combo_reset_timer := 0.0
var coyote_timer := 0.0
var wall_jump_timer := 0.0
var standing_body_shape: Shape2D
var sliding_body_shape: Shape2D
var standing_attack_shape: Shape2D
var sliding_attack_shape: Shape2D
var standing_body_position: Vector2
var standing_attack_position: Vector2
var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))

@onready var scrolling_camera: Camera2D = get_node_or_null(camera_path) as Camera2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var invulnerability_timer: Timer = $InvulnerabilityTimer
@onready var knockback_timer: Timer = $KnockbackTimer
@onready var hurt_material: ShaderMaterial = animated_sprite.material as ShaderMaterial


func _ready() -> void:
	standing_body_shape = body_shape.shape
	standing_attack_shape = attack_shape.shape
	standing_body_position = body_shape.position
	standing_attack_position = attack_shape.position
	var capsule := standing_body_shape.duplicate() as CapsuleShape2D
	capsule.radius *= 0.5
	capsule.height *= 0.5
	sliding_body_shape = capsule
	var rectangle := standing_attack_shape.duplicate() as RectangleShape2D
	rectangle.size *= 0.5
	sliding_attack_shape = rectangle
	health = max_health
	invulnerability_timer.timeout.connect(_end_invulnerability)
	add_to_group(&"player")
	animated_sprite.animation_changed.connect(_on_animation_changed)
	spawn_position = global_position
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		_apply_gravity(delta)
		move_and_slide()
		return
	if not knockback_timer.is_stopped():
		_apply_gravity(delta)
		move_and_slide()
		_keep_inside_camera()
		return
	_update_combo_timer(delta)
	wall_jump_timer = maxf(wall_jump_timer - delta, 0.0)
	if is_on_floor() and velocity.y >= 0.0:
		coyote_timer = coyote_time
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	var direction: float = Input.get_axis("ui_left", "ui_right")
	var wasd_direction: float = (
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	)
	if not is_zero_approx(wasd_direction):
		direction = wasd_direction

	var acceleration: float = ground_acceleration if is_on_floor() else air_acceleration
	if wall_jump_timer > 0.0 and not is_on_floor():
		pass # Preserve the push briefly even when holding toward the wall.
	elif is_sliding:
		velocity.x = move_toward(velocity.x, 0.0, slide_deceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * delta)
	_apply_gravity(delta)
	_handle_jump_input()

	move_and_slide()
	if is_on_floor():
		air_sweep_available = true

	var can_air_sweep := not action_locked or animated_sprite.animation == &"air_sweep"
	if Input.is_action_just_pressed("airslash") and air_sweep_available and can_air_sweep:
		air_sweep_available = false
		coyote_timer = 0.0
		velocity.y = -air_sweep_velocity
		action_locked = false
		animated_sprite.stop()
		_play_action(&"air_sweep")

	_keep_inside_camera()
	_update_facing()
	_update_animation()
	_handle_action_input()
	_update_attack_hitbox()


func _update_attack_hitbox() -> void:
	var animation := animated_sprite.animation
	var is_air_sweep := animation == &"air_sweep"
	if is_dead or not action_locked or not (_is_attack_animation(animation) or is_air_sweep):
		return
	# The wind-up and recovery frames do not deal damage.
	if animated_sprite.frame < 1 or animated_sprite.frame > 3:
		return
	var facing := -1.0 if animated_sprite.flip_h else 1.0
	attack_hitbox.position = Vector2(30.0 * facing, -24.0 if is_air_sweep else -8.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape.shape
	query.transform = attack_shape.global_transform
	query.collision_mask = attack_hitbox.collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var target := hit["collider"] as Area2D
		if target != null and target.has_method("receive_hit") and not attack_targets.has(target.get_instance_id()):
			attack_targets[target.get_instance_id()] = true
			var killed: bool = target.receive_hit(global_position)
			if killed and is_air_sweep:
				air_sweep_available = true


func reset_to_spawn() -> void:
	coins = 0
	coins_changed.emit(coins)
	health = max_health
	invulnerability_timer.stop()
	knockback_timer.stop()
	_end_invulnerability()
	health_changed.emit(health, max_health)
	global_position = spawn_position
	velocity = Vector2.ZERO
	is_dead = false
	action_locked = false
	air_sweep_available = true
	_set_slide_collision(false)
	attack_combo_step = 0
	attack_queued = false
	combo_reset_timer = 0.0
	coyote_timer = 0.0
	wall_jump_timer = 0.0
	animated_sprite.play(&"idle")


func add_coins(amount: int) -> void:
	if amount <= 0 or is_dead:
		return
	coins += amount
	coins_changed.emit(coins)


func play_hurt() -> void:
	_play_action(&"hurt")


func take_damage(amount: int, source_position: Vector2) -> bool:
	if is_dead or not invulnerability_timer.is_stopped() or amount <= 0:
		return false
	health = maxi(0, health - amount)
	if health == 0:
		play_death()
		return true
	health_changed.emit(health, max_health)
	invulnerability_timer.start(invulnerability_duration)
	hurt_material.set_shader_parameter("invulnerable", true)
	knockback_timer.start()
	var away := signf(global_position.x - source_position.x)
	if is_zero_approx(away):
		away = 1.0 if animated_sprite.flip_h else -1.0
	velocity = Vector2(away * knockback_speed, -knockback_lift)
	wall_jump_timer = 0.0
	_set_slide_collision(false)
	attack_queued = false
	coyote_timer = 0.0
	action_locked = false
	_play_action(&"hurt")
	return true


func _end_invulnerability() -> void:
	hurt_material.set_shader_parameter("invulnerable", false)


func play_death() -> void:
	if is_dead:
		return
	is_dead = true
	_set_slide_collision(false)
	health = 0
	invulnerability_timer.stop()
	knockback_timer.stop()
	_end_invulnerability()
	health_changed.emit(health, max_health)
	coyote_timer = 0.0
	action_locked = true
	wall_jump_timer = 0.0
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
	attack_targets.clear()
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
	if action_locked or is_dead or not animated_sprite.sprite_frames.has_animation(&"slide"):
		return
	var slide_direction := -1.0 if animated_sprite.flip_h else 1.0
	if not is_zero_approx(velocity.x):
		slide_direction = signf(velocity.x)
	_set_slide_collision(true)
	velocity.x = slide_direction * slide_speed
	_play_action(&"slide")


func _set_slide_collision(sliding: bool) -> void:
	is_sliding = sliding
	var body_position := standing_body_position
	var hit_position := standing_attack_position
	if sliding:
		body_position.y += standing_body_shape.get_rect().size.y * 0.25
		hit_position.y += standing_attack_shape.get_rect().size.y * 0.25
	body_shape.set_deferred("shape", sliding_body_shape if sliding else standing_body_shape)
	body_shape.set_deferred("position", body_position)
	attack_shape.set_deferred("shape", sliding_attack_shape if sliding else standing_attack_shape)
	attack_shape.set_deferred("position", hit_position)


func _on_animation_changed() -> void:
	attack_targets.clear()
	if is_sliding and animated_sprite.animation != &"slide":
		_set_slide_collision(false)


func _handle_jump_input() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		_try_jump()


func _try_jump() -> bool:
	if action_locked or is_dead or not knockback_timer.is_stopped():
		return false
	if not is_on_floor() and is_on_wall():
		var wall_normal := get_wall_normal()
		if absf(wall_normal.x) < 0.5:
			return false
		velocity = Vector2(signf(wall_normal.x) * wall_jump_push_speed, -jump_velocity)
		wall_jump_timer = wall_jump_control_delay
		coyote_timer = 0.0
		animated_sprite.flip_h = velocity.x < 0.0
		animated_sprite.play(&"jump")
		return true
	if is_on_floor() or coyote_timer > 0.0:
		coyote_timer = 0.0
		wall_jump_timer = 0.0
		velocity.y = -jump_velocity
		animated_sprite.play(&"jump")
		return true
	return false



func _play_action(animation_name: StringName) -> void:
	if action_locked or is_dead:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	action_locked = true
	attack_targets.clear()
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
		_set_slide_collision(false)
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
