extends "res://scripts/chunk_room_demo.gd"

const START_CAMERA_POSITION := Vector2(256.0, 0.0)

@export var randomize_seed_on_start := true

var seed_rng := RandomNumberGenerator.new()

@onready var player: PlayerController = $Player
@onready var autoscroll_camera: AutoscrollCamera = $AutoscrollCamera


func _ready() -> void:
	seed_rng.randomize()
	if randomize_seed_on_start:
		random_seed = _next_random_seed()
	graph_debug.visible = false
	hud.visible = false
	camera_control.enabled = false
	super._ready()
	_reset_gameplay_view()
	print("GameProper seed: %d" % random_seed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("generate_level"):
		_generate_rooms(_next_random_seed())
		print("GameProper seed: %d" % random_seed)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_validation_method"):
		use_dfs = not use_dfs
		_revalidate()
		get_viewport().set_input_as_handled()


func _generate_rooms(seed_value: int) -> void:
	super._generate_rooms(seed_value)
	if is_node_ready():
		_reset_gameplay_view()


func _render_rooms() -> void:
	(rooms as GameChunkSceneRenderer).layout_seed = random_seed
	rooms.rebuild(render_chunks)


func _reset_gameplay_view() -> void:
	autoscroll_camera.chunk_top = SCREEN_ORIGIN.y - TILE_SIZE.y * 0.5
	autoscroll_camera.chunk_bottom = SCREEN_ORIGIN.y + TILE_SIZE.y * 0.5
	autoscroll_camera.reset_to(START_CAMERA_POSITION)
	player.reset_to_spawn()


func _next_random_seed() -> int:
	return int(seed_rng.randi())
