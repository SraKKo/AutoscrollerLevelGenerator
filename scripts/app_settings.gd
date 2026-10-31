extends Node

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_RESOLUTION := Vector2i(1280, 720)
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

var window_mode: int = Window.MODE_FULLSCREEN
var resolution := DEFAULT_RESOLUTION
var vsync_enabled := true
var show_fps := false
var master_volume := 100.0
var music_volume := 100.0
var effects_volume := 100.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	window_mode = int(config.get_value("display", "window_mode", Window.MODE_FULLSCREEN))
	if window_mode not in [Window.MODE_WINDOWED, Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
		window_mode = Window.MODE_FULLSCREEN
	var stored_resolution: Variant = config.get_value("display", "resolution", DEFAULT_RESOLUTION)
	resolution = stored_resolution if stored_resolution is Vector2i and stored_resolution in RESOLUTIONS else DEFAULT_RESOLUTION
	vsync_enabled = bool(config.get_value("display", "vsync", true))
	show_fps = bool(config.get_value("display", "show_fps", false))
	master_volume = clampf(float(config.get_value("audio", "master", 100.0)), 0.0, 100.0)
	music_volume = clampf(float(config.get_value("audio", "music", 100.0)), 0.0, 100.0)
	effects_volume = clampf(float(config.get_value("audio", "effects", 100.0)), 0.0, 100.0)


func apply_settings() -> void:
	_set_volume(&"Master", master_volume)
	_set_volume(&"Music", music_volume)
	_set_volume(&"Effects", effects_volume)
	if DisplayServer.get_name() != "headless":
		var window := get_window()
		window.mode = window_mode
		if window_mode == Window.MODE_WINDOWED:
			var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
			window.size = Vector2i(mini(resolution.x, usable.size.x), mini(resolution.y, usable.size.y))
			window.position = usable.position + (usable.size - window.size) / 2
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	settings_changed.emit()


func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("display", "window_mode", window_mode)
	config.set_value("display", "resolution", resolution)
	config.set_value("display", "vsync", vsync_enabled)
	config.set_value("display", "show_fps", show_fps)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "effects", effects_volume)
	return config.save(SETTINGS_PATH)


func _set_volume(bus_name: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, value <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value / 100.0, 0.0001)))
