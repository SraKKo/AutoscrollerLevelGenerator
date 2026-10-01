extends "res://scripts/chunk_room_demo.gd"

const START_CAMERA_POSITION := Vector2(256.0, 0.0)

@onready var player: PlayerController = $Player
@onready var autoscroll_camera: AutoscrollCamera = $AutoscrollCamera


func _ready() -> void:
	graph_debug.visible = false
	hud.visible = false
	camera_control.enabled = false
	super._ready()
	_reset_gameplay_view()


func _generate_rooms(seed_value: int) -> void:
	super._generate_rooms(seed_value)
	if is_node_ready():
		_reset_gameplay_view()


func _render_rooms() -> void:
	rooms.rebuild(render_chunks)


func _reset_gameplay_view() -> void:
	autoscroll_camera.reset_to(START_CAMERA_POSITION)
	player.reset_to_spawn()
