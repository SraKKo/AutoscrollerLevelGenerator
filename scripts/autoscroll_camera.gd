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

# A brief slowdown buys one input near the trailing edge. Running ahead rearms it.
const EDGE_GRACE_TIME := 0.75
var edge_grace_left := EDGE_GRACE_TIME


func _physics_process(delta: float) -> void:
	if scrolling:
		var advance := scroll_speed * delta
		if is_instance_valid(player):
			var half_width := get_viewport_rect().size.x / (2.0 * zoom.x)
			var distance_from_left := player.global_position.x - (global_position.x - half_width)
			if distance_from_left >= 256.0:
				edge_grace_left = EDGE_GRACE_TIME
			elif distance_from_left <= 160.0 and edge_grace_left > 0.0:
				var grace_step := minf(delta, edge_grace_left)
				advance -= scroll_speed * 0.65 * grace_step
				edge_grace_left -= grace_step
		global_position.x += advance
	if target != null:
		var follow_weight := 1.0 - exp(-vertical_follow_speed * delta)
		global_position.y = lerpf(global_position.y, target.global_position.y, follow_weight)
	_clamp_vertical_position()

	if player:
		_handle_player_boundaries()


func reset_to(start_position: Vector2) -> void:
	edge_grace_left = EDGE_GRACE_TIME
	global_position = start_position
	_clamp_vertical_position()
	reset_smoothing()
	force_update_scroll()


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
	if player is PlayerController and player.is_dead:
		return
	var screen_width = get_viewport_rect().size.x / zoom.x
	var margin := 16.0

	var right_boundary = global_position.x + (screen_width / 2.0)
	if player.global_position.x > right_boundary - margin:
		global_position.x = player.global_position.x - (screen_width / 2.0) + margin
