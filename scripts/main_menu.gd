extends Control

var transitioning := false


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	%Play.pressed.connect(_play)
	%Settings.pressed.connect(_open_settings)
	%DebugScenes.pressed.connect(_open_debug)
	%DebugGraph.pressed.connect(_open_scene.bind("res://scenes/Debug/main.tscn"))
	%DebugChunks.pressed.connect(_open_scene.bind("res://scenes/Debug/chunk_room_demo.tscn"))
	%DebugGameplay.pressed.connect(_open_scene.bind("res://scenes/Debug/debug1.tscn"))
	%DebugBack.pressed.connect(_close_debug)
	%Quit.pressed.connect(func(): get_tree().quit())
	$SettingsPanel.closed.connect(_close_settings)
	%Play.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and $SettingsPanel.visible:
		get_viewport().set_input_as_handled()
		$SettingsPanel.close()
	elif event.is_action_pressed("ui_cancel") and %DebugPanel.visible:
		get_viewport().set_input_as_handled()
		_close_debug()


func _play() -> void:
	_open_scene("res://scenes/game_proper.tscn")


func _open_scene(scene_path: String) -> void:
	if transitioning:
		return
	transitioning = true
	if get_tree().change_scene_to_file(scene_path) != OK:
		transitioning = false
		%MenuStatus.text = "Could not open the scene. Please try again."
		%DebugPanel.hide()
		%MainPanel.show()


func _open_debug() -> void:
	%MainPanel.hide()
	%DebugPanel.show()
	%DebugGraph.grab_focus()


func _close_debug() -> void:
	%DebugPanel.hide()
	%MainPanel.show()
	%DebugScenes.grab_focus()


func _open_settings() -> void:
	%MainPanel.hide()
	$SettingsPanel.open()


func _close_settings() -> void:
	%MainPanel.show()
	%Settings.grab_focus()
