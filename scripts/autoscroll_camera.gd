class_name AutoscrollCamera
extends Camera2D

@export_range(0.0, 1000.0, 10.0) var scroll_speed := 220.0
@export var scrolling := true
@export var target_path: NodePath
@export_range(0.1, 20.0, 0.1) var vertical_follow_speed := 5.0
@export var chunk_top := -816.0
@export var chunk_bottom := 816.0
@export_range(0.0, 256.0, 1.0) var vertical_margin := 32.0

@onready var target: Node2D = get_node_or_null(target_path) as Node2D
@export var player: CharacterBody2D


func _physics_process(delta: float) -> void:
	if scrolling:
		global_position.x += scroll_speed * delta
	if target != null:
		var follow_weight := 1.0 - exp(-vertical_follow_speed * delta)
		global_position.y = lerpf(global_position.y, target.global_position.y, follow_weight)
	_clamp_vertical_position()

	if player:
		_handle_player_boundaries()


func reset_to(start_position: Vector2) -> void:
	global_position = start_position
	_clamp_vertical_position()
	reset_smoothing()


func _clamp_vertical_position() -> void:
	limit_top = ceili(chunk_top + vertical_margin)
	limit_bottom = floori(chunk_bottom - vertical_margin)
	var half_height := get_viewport_rect().size.y / (2.0 * zoom.y)
	var minimum_y := chunk_top + vertical_margin + half_height
	var maximum_y := chunk_bottom - vertical_margin - half_height
	if minimum_y > maximum_y:
		global_position.y = (chunk_top + chunk_bottom) * 0.5 - offset.y
	else:
		global_position.y = clampf(global_position.y, minimum_y - offset.y, maximum_y - offset.y)


func _handle_player_boundaries() -> void:
	var screen_width = get_viewport_rect().size.x / zoom.x

	var left_boundary = global_position.x - (screen_width / 2.0)
	
	var margin := 16.0
	
	if player.global_position.x < left_boundary + margin:
		player.global_position.x = left_boundary + margin

	var right_boundary = global_position.x + (screen_width / 2.0)
	if player.global_position.x > right_boundary - margin:
		global_position.x = player.global_position.x - (screen_width / 2.0) + margin
