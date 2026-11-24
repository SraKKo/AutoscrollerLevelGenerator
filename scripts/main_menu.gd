extends Control

const RunSeed := preload("res://scripts/run_seed.gd")

var transitioning := false


func _ready() -> void:
	SFX.stop_all()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	%Play.pressed.connect(_play)
	%SeedInput.text_submitted.connect(_play.unbind(1))
	%Settings.pressed.connect(_open_settings)
	%DebugScenes.pressed.connect(_open_debug)
	%DebugGraph.pressed.connect(_open_scene.bind("res://scenes/Debug/main.tscn"))
	%DebugChunks.pressed.connect(_open_scene.bind("res://scenes/Debug/chunk_room_demo.tscn"))
	%DebugGameplay.pressed.connect(_open_scene.bind("res://scenes/Debug/debug1.tscn"))
	%DebugBack.pressed.connect(_close_debug)
	%Quit.pressed.connect(func(): get_tree().quit())
	$SettingsPanel.closed.connect(_close_settings)
	%Play.grab_focus()


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or transitioning or not %MainPanel.visible:
		return
	if event is InputEventKey and event.keycode == KEY_F3 and event.pressed and not event.echo:
		%SeedRow.visible = not %SeedRow.visible
		%MenuStatus.text = ""
		if %SeedRow.visible:
			%SeedInput.grab_focus()
		else:
			%SeedInput.clear()
			%Play.grab_focus()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and $SettingsPanel.visible:
		get_viewport().set_input_as_handled()
		$SettingsPanel.close()
	elif event.is_action_pressed("ui_cancel") and %DebugPanel.visible:
		get_viewport().set_input_as_handled()
		_close_debug()


func _play() -> void:
	if transitioning:
		return
	var value: String = %SeedInput.text.strip_edges() if %SeedRow.is_visible_in_tree() else ""
	if not value.is_empty() and not RunSeed.is_valid(value):
		%MenuStatus.text = "Enter a whole number within the signed 64-bit range."
		%SeedInput.grab_focus()
		%SeedInput.select_all()
		return
	RunSeed.pending = null if value.is_empty() else value.to_int()
	_open_scene("res://scenes/game_proper.tscn")
	if not transitioning:
		RunSeed.pending = null


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
