extends Node2D

@export var random_seed := 54321

var level: Dictionary = {}
var use_dfs := false

@onready var level_generator: AbstractGraphLevelGenerator = $LevelGenerator
@onready var graph_renderer: AbstractGraphRenderer = $GraphRenderer
@onready var camera_control: LevelCameraControl = $CameraControl
@onready var hud: GraphDemoHud = $HUD

func _ready() -> void:
	_generate_level(random_seed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("generate_level"):
		_generate_level(random_seed + 1)
	elif event.is_action_pressed("toggle_validation_method"):
		use_dfs = not use_dfs
		_revalidate_current_level()

func _generate_level(seed_value: int) -> void:
	random_seed = seed_value
	level = level_generator.generate(random_seed)
	_revalidate_current_level()
	camera_control.fit_to_rooms(
		graph_renderer.get_node_positions(),
		graph_renderer.get_node_size()
	)

func _revalidate_current_level() -> void:
	if level.is_empty():
		return

	var method: String = PlatformGraphValidator.METHOD_DFS if use_dfs else PlatformGraphValidator.METHOD_BFS
	level["validation"] = PlatformGraphValidator.validate_path(
		level["graph"] as Dictionary,
		int(level["start_id"]),
		int(level["goal_id"]),
		method
	)
	graph_renderer.display_level(level)
	hud.update_level(level, use_dfs)
