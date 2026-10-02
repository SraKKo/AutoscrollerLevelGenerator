class_name AutoscrollCamera
extends Camera2D

@export_range(0.0, 1000.0, 10.0) var scroll_speed := 220.0
@export var scrolling := true
@export var target_path: NodePath
@export_range(0.1, 20.0, 0.1) var vertical_follow_speed := 5.0

@onready var target: Node2D = get_node_or_null(target_path) as Node2D
@export var player: CharacterBody2D


func _physics_process(delta: float) -> void:
	if scrolling:
		global_position.x += scroll_speed * delta
	if target != null:
		var follow_weight := 1.0 - exp(-vertical_follow_speed * delta)
		global_position.y = lerpf(global_position.y, target.global_position.y, follow_weight)

		if player:
			_handle_player_boundaries()


func reset_to(start_position: Vector2) -> void:
	global_position = start_position
	reset_smoothing()


func _handle_player_boundaries() -> void:
	var screen_width = get_viewport_rect().size.x

	var left_boundary = global_position.x - (screen_width / 2.0)
	
	var margin := 16.0
	
	if player.global_position.x < left_boundary + margin:
		player.global_position.x = left_boundary + margin

	var right_boundary = global_position.x + (screen_width / 2.0)
	if player.global_position.x > right_boundary - margin:
		global_position.x = player.global_position.x - (screen_width / 2.0) + margin
