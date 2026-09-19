class_name LevelCameraControl
extends Camera2D

@export var move_speed := 1600.0
@export var zoom_speed := 0.12
@export var room_margin := 96.0
@export var min_zoom := 0.05
@export var max_zoom := 3.0

func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0

	if direction != Vector2.ZERO:
		position += direction.normalized() * move_speed * delta / max(zoom.x, 0.1)

	if Input.is_key_pressed(KEY_E):
		_change_zoom(1.0 + zoom_speed * delta * 8.0)
	elif Input.is_key_pressed(KEY_Q):
		_change_zoom(1.0 - zoom_speed * delta * 8.0)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_change_zoom(1.0 + zoom_speed)
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_change_zoom(1.0 - zoom_speed)

func fit_to_rooms(room_positions: Array[Vector2], room_size: Vector2) -> void:
	if room_positions.is_empty():
		return

	var half_room_size: Vector2 = room_size * 0.5
	var first_position: Vector2 = room_positions.front()
	var min_point: Vector2 = first_position - half_room_size
	var max_point: Vector2 = first_position + half_room_size

	for room_position in room_positions:
		min_point = min_point.min(room_position - half_room_size)
		max_point = max_point.max(room_position + half_room_size)

	var margin := Vector2(room_margin * 2.0, room_margin * 2.0)
	var content_size: Vector2 = (max_point - min_point) + margin
	var viewport_size: Vector2 = get_viewport_rect().size
	var zoom_value: float = min(viewport_size.x / content_size.x, viewport_size.y / content_size.y)

	position = (min_point + max_point) * 0.5
	zoom_value = clampf(zoom_value, min_zoom, max_zoom)
	zoom = Vector2(zoom_value, zoom_value)

func _change_zoom(multiplier: float) -> void:
	var next_zoom: float = clampf(zoom.x * multiplier, min_zoom, max_zoom)
	zoom = Vector2(next_zoom, next_zoom)
