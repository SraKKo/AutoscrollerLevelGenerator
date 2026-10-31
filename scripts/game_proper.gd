extends "res://scripts/chunk_room_demo.gd"

const START_CAMERA_LEAD_RATIO := 0.25
const POINTS_PER_SECOND := 2.0

var elapsed_time := 0.0
var score := 0
var run_over := false

@onready var player: PlayerController = $Player
@onready var autoscroll_camera: AutoscrollCamera = $AutoscrollCamera
@onready var game_ui: CanvasLayer = $GameUI
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var death_screen: CanvasLayer = $DeathScreen


func _ready() -> void:
	player.died.connect(_on_player_died)
	player.pickup_score_changed.connect(_on_pickup_score_changed)
	player.animated_sprite.animation_finished.connect(_on_player_animation_finished)
	death_screen.retry_requested.connect(restart_run.bind(false))
	death_screen.new_run_requested.connect(restart_run.bind(true))
	death_screen.menu_requested.connect(_return_to_menu)
	graph_debug.visible = false
	hud.visible = false
	camera_control.enabled = false
	super._ready()
	_reset_gameplay_view()


func _process(delta: float) -> void:
	if run_over:
		return
	elapsed_time += delta
	_refresh_score()


func _on_pickup_score_changed(_total_score: int) -> void:
	if not run_over:
		_refresh_score()


func _refresh_score() -> void:
	var next_score := floori(elapsed_time * POINTS_PER_SECOND) + player.pickup_score
	if next_score != score:
		score = next_score
		game_ui.update_score(score)


func _unhandled_input(event: InputEvent) -> void:
	if not run_over:
		super._unhandled_input(event)


func _on_player_died() -> void:
	if run_over:
		return
	run_over = true
	autoscroll_camera.scrolling = false
	pause_menu.pause_enabled = false
	if player.animated_sprite.animation != &"death":
		_show_death_screen.call_deferred()


func _on_player_animation_finished() -> void:
	if run_over and player.animated_sprite.animation == &"death":
		_show_death_screen()


func _show_death_screen() -> void:
	if not run_over or death_screen.get_node("Root").visible:
		return
	death_screen.show_result(score, player.coins, elapsed_time, random_seed)
	get_tree().paused = true


func restart_run(new_seed: bool = false) -> void:
	var next_seed := random_seed
	if new_seed:
		next_seed = randi_range(0, 2147483647)
		if next_seed == random_seed:
			next_seed += 1
	death_screen.hide_result()
	get_tree().paused = false
	_generate_rooms(next_seed)


func _return_to_menu() -> void:
	get_tree().paused = false
	if get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn") != OK:
		get_tree().paused = true


func _generate_rooms(seed_value: int) -> void:
	super._generate_rooms(seed_value)
	if is_node_ready():
		_reset_gameplay_view()


func _render_rooms() -> void:
	(rooms as GameChunkSceneRenderer).layout_seed = random_seed
	rooms.rebuild(render_chunks)


func _reset_gameplay_view() -> void:
	elapsed_time = 0.0
	score = 0
	run_over = false
	game_ui.update_score(0, true)
	pause_menu.pause_enabled = true
	autoscroll_camera.scrolling = true
	autoscroll_camera.chunk_top = SCREEN_ORIGIN.y - TILE_SIZE.y * 0.5
	autoscroll_camera.chunk_bottom = SCREEN_ORIGIN.y + TILE_SIZE.y * 0.5
	player.reset_to_spawn()
	var visible_width := autoscroll_camera.get_viewport_rect().size.x / autoscroll_camera.zoom.x
	var camera_start := player.global_position
	camera_start.x += visible_width * START_CAMERA_LEAD_RATIO - autoscroll_camera.offset.x
	autoscroll_camera.reset_to(camera_start)
