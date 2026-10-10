extends CharacterBody2D

enum Kind { MELEE, MAGE, SMALL_MUSHROOM, BIG_MUSHROOM }
enum State { IDLE, WINDUP, RECOVERY, HURT, DEAD }

const PROJECTILE := preload("res://scenes/Enemies/MageProjectile.tscn")

@export var kind: Kind = Kind.MELEE
@export var health := 2
@export var move_speed := 75.0
@export var detection_range := 240.0
@export var attack_range := 36.0
@export var patrol_distance := 80.0
@export var windup_time := 0.45
@export var recovery_time := 1.0

var state: State = State.IDLE
var facing := -1.0
var spawn_position: Vector2
var player: PlayerController
var active := false
var is_dead := false
var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ledge: RayCast2D = $LedgeRay
@onready var wall: RayCast2D = $WallRay
@onready var timer: Timer = $StateTimer
@onready var damage_area: Area2D = $DamageArea
@onready var detection_area: Area2D = get_node_or_null("DetectionArea") as Area2D


func _ready() -> void:
	spawn_position = global_position
	timer.timeout.connect(_on_state_timeout)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play(&"idle")
	_update_facing()


func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		var half_width := get_viewport_rect().size.x / (2.0 * camera.zoom.x)
		var center := camera.get_screen_center_position()
		if global_position.x < center.x - half_width - 100.0:
			queue_free()
			return
		if not active and global_position.x <= center.x + half_width - 24.0:
			active = true
	else:
		active = true
	if not active or is_dead:
		return
	if not is_instance_valid(player):
		for candidate in get_tree().get_nodes_in_group(&"player"):
			if candidate is PlayerController:
				player = candidate
				break
	velocity.y = minf(velocity.y + gravity * delta, 1000.0)
	velocity.x = 0.0
	if state == State.IDLE:
		_choose_action()
	move_and_slide()
	if kind == Kind.SMALL_MUSHROOM and state != State.HURT:
		_damage_overlaps()


func _choose_action() -> void:
	var sees_player := is_instance_valid(player) and not player.is_dead
	var offset := Vector2.ZERO
	if sees_player:
		offset = player.global_position - global_position
		if kind == Kind.MAGE:
			sees_player = detection_area != null and detection_area.overlaps_body(player)
		else:
			sees_player = absf(offset.x) <= detection_range and absf(offset.y) <= 36.0
	if sees_player and kind != Kind.SMALL_MUSHROOM:
		facing = -1.0 if offset.x < 0.0 else 1.0
		_update_facing()
		if kind == Kind.MAGE or absf(offset.x) <= attack_range:
			state = State.WINDUP
			sprite.play(&"attack")
			if windup_time <= 0.0:
				_on_state_timeout()
				return
			# Hold the anticipation pose until the attack becomes active.
			sprite.pause()
			timer.start(windup_time)
			return
	if kind == Kind.MAGE:
		sprite.play(&"idle")
		return
	if not sees_player or kind == Kind.SMALL_MUSHROOM:
		if absf(global_position.x - spawn_position.x) >= patrol_distance:
			facing = -1.0 if global_position.x > spawn_position.x else 1.0
	_update_facing()
	ledge.force_raycast_update()
	wall.force_raycast_update()
	if is_on_floor() and (not ledge.is_colliding() or wall.is_colliding()):
		if not sees_player or kind == Kind.SMALL_MUSHROOM:
			facing *= -1.0
			sprite.play(&"idle")
		return
	if absf(global_position.x - spawn_position.x + facing) <= patrol_distance:
		velocity.x = facing * move_speed
	sprite.play(&"walk" if velocity.x != 0.0 else &"idle")


func _update_facing() -> void:
	# Enemy textures face left in their original orientation.
	sprite.flip_h = facing > 0.0
	ledge.position.x = facing * 14.0
	wall.target_position.x = facing * 18.0
	damage_area.position.x = 0.0 if kind == Kind.SMALL_MUSHROOM else facing * 24.0


func receive_hit() -> bool:
	if is_dead:
		return false
	health -= 1
	timer.stop()
	velocity.x = 0.0
	if health <= 0:
		is_dead = true
		state = State.DEAD
		$Hurtbox.set_deferred("collision_layer", 0)
		sprite.play(&"death")
		return true
	state = State.HURT
	sprite.play(&"hurt")
	timer.start(0.4)
	return false


func _on_state_timeout() -> void:
	if state == State.WINDUP:
		sprite.play(&"attack")
		sprite.frame = 2
		if kind == Kind.MAGE:
			if is_instance_valid(player) and not player.is_dead and detection_area.overlaps_body(player):
				var shot = PROJECTILE.instantiate()
				shot.position = get_parent().to_local(player.global_position + Vector2(0, -12))
				get_parent().add_child(shot)
		else:
			_damage_overlaps()
		state = State.RECOVERY
		timer.start(recovery_time)
	elif state == State.RECOVERY or state == State.HURT:
		state = State.IDLE
		sprite.play(&"idle")


func _damage_overlaps() -> void:
	# Query the updated facing immediately, without waiting for Area2D overlaps.
	var shape: CollisionShape2D = damage_area.get_node("CollisionShape2D")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	query.collision_mask = 1
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var body: Object = hit["collider"]
		if body is PlayerController and not body.is_dead:
			body.take_damage(1, global_position)


func _on_animation_finished() -> void:
	if is_dead:
		queue_free()
	elif state == State.RECOVERY:
		sprite.play(&"idle")
