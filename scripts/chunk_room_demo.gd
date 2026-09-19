extends Node2D

const CHUNK_TEXTURES := {
	"Start": preload("res://Assets/Chunks/Test/Start.png"),
	"Finish": preload("res://Assets/Chunks/Test/Finish.png"),
	"StraightRoom": preload("res://Assets/Chunks/Test/StraightRoom.png"),
	"StraightUpper": preload("res://Assets/Chunks/Test/StraightUpper.png"),
	"StraightLower": preload("res://Assets/Chunks/Test/StraightLower.png"),
	"GoingUp": preload("res://Assets/Chunks/Test/GoingUp.png"),
	"GoingDown": preload("res://Assets/Chunks/Test/GoingDown.png"),
	"RiseToUpper": preload("res://Assets/Chunks/Test/RiseToUpper.png"),
	"DropToLower": preload("res://Assets/Chunks/Test/DropToLower.png"),
	"UpperToMiddle": preload("res://Assets/Chunks/Test/UpperToMiddle.png"),
	"LowerToMiddle": preload("res://Assets/Chunks/Test/LowerToMiddle.png"),
	"SplitRoom": preload("res://Assets/Chunks/Test/SplitRoom.png"),
	"DoubleStraight": preload("res://Assets/Chunks/Test/DoubleStraight.png"),
	"KeepUpper": preload("res://Assets/Chunks/Test/KeepUpper.png"),
	"KeepLower": preload("res://Assets/Chunks/Test/KeepLower.png"),
	"DeadEnd": preload("res://Assets/Chunks/Test/DeadEnd.png"),
	"DeadEndUpper": preload("res://Assets/Chunks/Test/DeadEndUpper.png"),
	"DeadEndLower": preload("res://Assets/Chunks/Test/DeadEndLower.png"),
}

const CHUNK_PIXEL_SIZE := Vector2(1088.0, 544.0)
const ROOM_SCALE := Vector2.ONE
const TILE_SIZE := Vector2(1088.0, 544.0)
const ROOM_MARGIN := 96.0
const SCREEN_ORIGIN := Vector2.ZERO

const LEVEL_UPPER := 136
const LEVEL_MIDDLE := 272
const LEVEL_LOWER := 408

@export var random_seed := 54321
@export_range(7, 30, 1) var room_count := 12
@export var show_graph_debug := false
@export var camera_move_speed := 1600.0
@export var camera_zoom_speed := 0.12

var rng := RandomNumberGenerator.new()
var level: Dictionary = {}
var render_chunks: Array = []
var use_dfs := false
var camera: Camera2D

@onready var hud_layer: CanvasLayer = $HUD
@onready var hud_label: Label = $HUD/Panel/Info

func _ready() -> void:
	_setup_camera()
	_generate_rooms(random_seed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("generate_level"):
		_generate_rooms(int(Time.get_unix_time_from_system()))
	elif event.is_action_pressed("toggle_validation_method"):
		use_dfs = not use_dfs
		_revalidate()
	elif event is InputEventMouseButton and event.pressed:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(1.0 + camera_zoom_speed)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(1.0 - camera_zoom_speed)

func _process(delta: float) -> void:
	if camera == null:
		return

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
		camera.position += direction.normalized() * camera_move_speed * delta / max(camera.zoom.x, 0.1)

	if Input.is_key_pressed(KEY_E):
		_zoom_camera(1.0 + camera_zoom_speed * delta * 8.0)
	elif Input.is_key_pressed(KEY_Q):
		_zoom_camera(1.0 - camera_zoom_speed * delta * 8.0)

func _generate_rooms(seed_value: int) -> void:
	random_seed = seed_value
	rng.seed = random_seed
	var chunk_names: Array[String] = _generate_chunk_sequence()
	_build_render_chunks(chunk_names)
	level = _build_level_graph(chunk_names)
	_build_room_nodes()
	_revalidate()

func _generate_chunk_sequence() -> Array[String]:
	var chunks: Array[String] = ["Start"]
	var current_level: int = LEVEL_MIDDLE
	var dead_end_count: int = 0
	var dead_end_target: int = clampi(int(ceil(float(room_count) / 6.0)), 1, 3)
	var target_before_finish: int = maxi(room_count - 1, 6)

	while chunks.size() < target_before_finish:
		if dead_end_count < dead_end_target:
			if current_level != LEVEL_MIDDLE:
				chunks.append(_chunk_to_middle(current_level))
				current_level = LEVEL_MIDDLE
				continue

			current_level = _append_dead_end_section(chunks)
			dead_end_count += 1
			continue

		var roll: float = rng.randf()
		if current_level == LEVEL_MIDDLE:
			if roll < 0.45:
				chunks.append("StraightRoom")
			elif roll < 0.68:
				chunks.append("RiseToUpper")
				current_level = LEVEL_UPPER
			elif roll < 0.91:
				chunks.append("DropToLower")
				current_level = LEVEL_LOWER
			else:
				current_level = _append_dead_end_section(chunks)
				dead_end_count += 1
		elif current_level == LEVEL_UPPER:
			if roll < 0.42:
				chunks.append("StraightUpper")
			elif roll < 0.68:
				chunks.append("GoingDown")
				current_level = LEVEL_LOWER
			else:
				chunks.append("UpperToMiddle")
				current_level = LEVEL_MIDDLE
		else:
			if roll < 0.42:
				chunks.append("StraightLower")
			elif roll < 0.68:
				chunks.append("GoingUp")
				current_level = LEVEL_UPPER
			else:
				chunks.append("LowerToMiddle")
				current_level = LEVEL_MIDDLE

	if current_level != LEVEL_MIDDLE:
		chunks.append(_chunk_to_middle(current_level))

	chunks.append("Finish")
	return chunks

func _append_dead_end_section(chunks: Array[String]) -> int:
	chunks.append("SplitRoom")
	var straight_count: int = rng.randi_range(0, 2)
	for _index in range(straight_count):
		chunks.append("DoubleStraight")

	if rng.randf() < 0.5:
		chunks.append("KeepUpper")
		return LEVEL_UPPER

	chunks.append("KeepLower")
	return LEVEL_LOWER

func _chunk_to_middle(current_level: int) -> String:
	return "UpperToMiddle" if current_level == LEVEL_UPPER else "LowerToMiddle"

func _build_render_chunks(chunk_names: Array[String]) -> void:
	render_chunks.clear()
	for index in range(chunk_names.size()):
		var chunk_name: String = chunk_names[index]
		render_chunks.append({
			"chunk_name": chunk_name,
			"world_position": SCREEN_ORIGIN + Vector2(float(index) * TILE_SIZE.x, 0.0),
		})

func _build_level_graph(chunk_names: Array[String]) -> Dictionary:
	var graph: Dictionary = {}
	var dead_end_ids: Array[int] = []

	for index in range(chunk_names.size()):
		graph[index] = []
		if index < chunk_names.size() - 1:
			(graph[index] as Array).append(index + 1)

	var next_id: int = chunk_names.size()
	for index in range(chunk_names.size()):
		if chunk_names[index] != "SplitRoom":
			continue
		graph[next_id] = []
		(graph[index] as Array).append(next_id)
		dead_end_ids.append(next_id)
		next_id += 1

	return {
		"seed": random_seed,
		"graph": graph,
		"start_id": 0,
		"goal_id": chunk_names.size() - 1,
		"dead_end_ids": dead_end_ids,
		"dead_end_count": dead_end_ids.size(),
		"validation": {},
	}

func _build_room_nodes() -> void:
	for child in get_children():
		if child != camera and child != hud_layer:
			child.queue_free()

	for chunk_data in render_chunks:
		var room: Dictionary = chunk_data as Dictionary
		var sprite := Sprite2D.new()
		var chunk_name: String = str(room["chunk_name"])
		sprite.name = "Chunk_%s" % chunk_name
		sprite.texture = CHUNK_TEXTURES[chunk_name] as Texture2D
		sprite.position = room["world_position"] as Vector2
		sprite.scale = ROOM_SCALE
		add_child(sprite)

	_fit_camera_to_rooms()

func _revalidate() -> void:
	if level.is_empty():
		return

	var method: String = PlatformGraphValidator.METHOD_DFS if use_dfs else PlatformGraphValidator.METHOD_BFS
	level["validation"] = PlatformGraphValidator.validate_path(
		level["graph"] as Dictionary,
		int(level["start_id"]),
		int(level["goal_id"]),
		method
	)
	_update_hud()
	queue_redraw()

func _draw() -> void:
	if not show_graph_debug:
		return

	for index in range(render_chunks.size() - 1):
		var from_chunk: Dictionary = render_chunks[index] as Dictionary
		var to_chunk: Dictionary = render_chunks[index + 1] as Dictionary
		var from_position: Vector2 = from_chunk["world_position"] as Vector2
		var to_position: Vector2 = to_chunk["world_position"] as Vector2
		draw_line(from_position, to_position, Color("#22c55e"), 7.0)

func _update_hud() -> void:
	if level.is_empty():
		return

	var method: String = "DFS" if use_dfs else "BFS"
	var validation: Dictionary = level["validation"] as Dictionary
	var status: String = "GRYWALNY" if bool(validation["playable"]) else "NIEGRYWALNY"
	var lines := PackedStringArray([
		"Proceduralny poziom z nowych chunkow PNG",
		"Seed: %s | Metoda: %s | Status: %s | Slepe zaulki: %s" % [
			level["seed"], method, status, level["dead_end_count"],
		],
		"R - nowy uklad, V - BFS/DFS, WASD/strzalki - kamera, Q/E/kolko - zoom",
		"Chunki 1088x544 | Polaczenia zgodne z portami Upper/Middle/Lower",
	])
	hud_label.text = "\n".join(lines)

func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "GeneratedRoomsCamera"
	camera.enabled = true
	add_child(camera)

func _fit_camera_to_rooms() -> void:
	if render_chunks.is_empty():
		return

	var half_room_size: Vector2 = CHUNK_PIXEL_SIZE * ROOM_SCALE * 0.5
	var first_room: Dictionary = render_chunks.front() as Dictionary
	var first_position: Vector2 = first_room["world_position"] as Vector2
	var min_point: Vector2 = first_position - half_room_size
	var max_point: Vector2 = first_position + half_room_size

	for room_data in render_chunks:
		var room: Dictionary = room_data as Dictionary
		var room_position: Vector2 = room["world_position"] as Vector2
		min_point = min_point.min(room_position - half_room_size)
		max_point = max_point.max(room_position + half_room_size)

	var content_size: Vector2 = (max_point - min_point) + Vector2(ROOM_MARGIN * 2.0, ROOM_MARGIN * 2.0)
	var viewport_size: Vector2 = get_viewport_rect().size
	var zoom_value: float = min(viewport_size.x / content_size.x, viewport_size.y / content_size.y)

	camera.position = (min_point + max_point) * 0.5
	camera.zoom = Vector2(zoom_value, zoom_value)

func _zoom_camera(multiplier: float) -> void:
	if camera == null:
		return

	var next_zoom: float = clamp(camera.zoom.x * multiplier, 0.05, 3.0)
	camera.zoom = Vector2(next_zoom, next_zoom)
