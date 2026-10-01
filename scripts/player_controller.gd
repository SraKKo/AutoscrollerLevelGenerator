class_name PlayerController
extends CharacterBody2D

@export_range(50.0, 1000.0, 10.0) var move_speed := 360.0
@export_range(0.0, 200.0, 1.0) var screen_margin := 56.0
@export var camera_path: NodePath

var spawn_position := Vector2.ZERO

@onready var scrolling_camera: Camera2D = get_node(camera_path) as Camera2D


func _ready() -> void:
	spawn_position = global_position


func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd_direction: Vector2 = Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	if wasd_direction != Vector2.ZERO:
		direction = wasd_direction.normalized()

	velocity = direction * move_speed
	move_and_slide()
	_keep_inside_camera()


func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO


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
