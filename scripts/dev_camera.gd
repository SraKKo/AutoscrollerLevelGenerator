extends LevelCameraControl

@onready var game_camera: Camera2D = $"../AutoscrollCamera"
@onready var pause_menu = $"../PauseMenu"
@onready var hint: CanvasLayer = $Overlay


func _ready() -> void:
	set_process(false)
	set_process_input(OS.is_debug_build())
	set_process_unhandled_input(false)


func _input(event: InputEvent) -> void:
	var toggle: bool = event is InputEventKey and event.keycode == KEY_F3 and event.pressed and not event.echo
	if enabled and (toggle or event.is_action_pressed("ui_cancel")):
		game_camera.make_current()
		enabled = false
		set_process(false)
		set_process_unhandled_input(false)
		hint.hide()
		get_tree().paused = false
	elif toggle and not get_tree().paused and pause_menu.pause_enabled:
		global_position = game_camera.get_screen_center_position()
		zoom = game_camera.zoom
		get_tree().paused = true
		enabled = true
		make_current()
		set_process(true)
		set_process_unhandled_input(true)
		$Overlay/StageSeed.text = "Stage seed: " + str(get_parent().random_seed)
		hint.show()
	else:
		return
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if enabled:
		get_tree().paused = false
