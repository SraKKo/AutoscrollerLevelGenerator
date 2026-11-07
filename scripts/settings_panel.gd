extends Control

signal closed

const WINDOW_MODES: Array[int] = [Window.MODE_WINDOWED, Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]

@onready var display_mode: OptionButton = %DisplayMode
@onready var resolution_option: OptionButton = %Resolution
@onready var vsync: CheckButton = %VSync
@onready var fps_counter: CheckButton = %ShowFPS
@onready var master: HSlider = %MasterVolume
@onready var music: HSlider = %MusicVolume
@onready var effects: HSlider = %EffectsVolume
@onready var status: Label = %SettingsStatus


func _ready() -> void:
	display_mode.add_item("Windowed")
	display_mode.add_item("Borderless Fullscreen")
	display_mode.add_item("Exclusive Fullscreen")
	for size in AppSettings.RESOLUTIONS:
		resolution_option.add_item("%d × %d" % [size.x, size.y])
	display_mode.item_selected.connect(_on_display_mode_selected)
	vsync.toggled.connect(func(enabled: bool): vsync.text = "On" if enabled else "Off")
	fps_counter.toggled.connect(func(enabled: bool): fps_counter.text = "On" if enabled else "Off")
	master.value_changed.connect(func(value: float): %MasterValue.text = "%d%%" % roundi(value))
	music.value_changed.connect(func(value: float): %MusicValue.text = "%d%%" % roundi(value))
	effects.value_changed.connect(func(value: float): %EffectsValue.text = "%d%%" % roundi(value))
	%Apply.pressed.connect(_apply)
	%Cancel.pressed.connect(close)
	%Defaults.pressed.connect(_defaults)
	hide()


func open() -> void:
	display_mode.select(WINDOW_MODES.find(AppSettings.window_mode))
	resolution_option.select(AppSettings.RESOLUTIONS.find(AppSettings.resolution))
	vsync.button_pressed = AppSettings.vsync_enabled
	fps_counter.button_pressed = AppSettings.show_fps
	master.value = AppSettings.master_volume
	music.value = AppSettings.music_volume
	effects.value = AppSettings.effects_volume
	_refresh_values()
	_on_display_mode_selected(display_mode.selected)
	status.text = "Select Apply to save your changes."
	show()
	display_mode.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _apply() -> void:
	AppSettings.window_mode = WINDOW_MODES[display_mode.selected]
	AppSettings.resolution = AppSettings.RESOLUTIONS[resolution_option.selected]
	AppSettings.vsync_enabled = vsync.button_pressed
	AppSettings.show_fps = fps_counter.button_pressed
	AppSettings.master_volume = master.value
	AppSettings.music_volume = music.value
	AppSettings.effects_volume = effects.value
	AppSettings.apply_settings()
	if AppSettings.save_settings() != OK:
		status.text = "Could not save settings. Please try again."
		return
	close()


func _defaults() -> void:
	display_mode.select(1)
	resolution_option.select(0)
	vsync.button_pressed = true
	fps_counter.button_pressed = false
	master.value = 100
	music.value = 100
	effects.value = 100
	_refresh_values()
	_on_display_mode_selected(1)
	status.text = "Defaults restored. Select Apply to save."


func _on_display_mode_selected(index: int) -> void:
	resolution_option.disabled = WINDOW_MODES[index] != Window.MODE_WINDOWED
	%ResolutionHint.text = "Window size" if index == 0 else "Fullscreen uses your monitor's resolution."


func _refresh_values() -> void:
	vsync.text = "On" if vsync.button_pressed else "Off"
	fps_counter.text = "On" if fps_counter.button_pressed else "Off"
	%MasterValue.text = "%d%%" % roundi(master.value)
	%MusicValue.text = "%d%%" % roundi(music.value)
	%EffectsValue.text = "%d%%" % roundi(effects.value)
