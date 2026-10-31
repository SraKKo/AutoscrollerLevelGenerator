extends CanvasLayer

var transitioning := false
var pause_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Root.hide()
	%Resume.pressed.connect(func(): set_paused(false))
	%Restart.pressed.connect(_restart)
	%PauseSettings.pressed.connect(_open_settings)
	%MainMenu.pressed.connect(_main_menu)
	$Root/SettingsPanel.closed.connect(_close_settings)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo() and not transitioning and pause_enabled:
		get_viewport().set_input_as_handled()
		if $Root/SettingsPanel.visible:
			$Root/SettingsPanel.close()
		else:
			set_paused(not get_tree().paused)


func set_paused(value: bool) -> void:
	if value and not pause_enabled:
		return
	get_tree().paused = value
	$Root.visible = value
	if value:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		%PausePanel.show()
		$Root/SettingsPanel.hide()
		%Resume.grab_focus()


func _open_settings() -> void:
	%PausePanel.hide()
	$Root/SettingsPanel.open()


func _close_settings() -> void:
	%PausePanel.show()
	%PauseSettings.grab_focus()


func _restart() -> void:
	if transitioning:
		return
	transitioning = true
	set_paused(false)
	if get_tree().reload_current_scene() != OK:
		transitioning = false
		set_paused(true)


func _main_menu() -> void:
	if transitioning:
		return
	transitioning = true
	set_paused(false)
	if get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn") != OK:
		transitioning = false
		set_paused(true)
