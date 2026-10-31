extends CanvasLayer


func _ready() -> void:
	AppSettings.settings_changed.connect(_apply_visibility)
	$UpdateTimer.timeout.connect(_update_fps)
	_apply_visibility()


func _apply_visibility() -> void:
	$Label.visible = AppSettings.show_fps
	_update_fps()


func _update_fps() -> void:
	if $Label.visible:
		$Label.text = "FPS  %d" % Engine.get_frames_per_second()
