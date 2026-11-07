extends CanvasLayer

var transitioning := false
var generate_level: Callable
var last_seed := 0

@onready var seed_input: LineEdit = $Root/SeedPanel/Padding/Content/Row/SeedInput
@onready var seed_status: Label = $Root/SeedPanel/Padding/Content/Status


func _ready() -> void:
	$Root/MainMenu.pressed.connect(_return_to_menu)
	if get_parent().has_method("_generate_rooms"):
		generate_level = Callable(get_parent(), "_generate_rooms")
	elif get_parent().has_method("_generate_level"):
		generate_level = Callable(get_parent(), "_generate_level")
	$Root/SeedPanel.visible = generate_level.is_valid()
	if generate_level.is_valid():
		last_seed = int(get_parent().get("random_seed"))
		seed_input.text = str(last_seed)
		seed_input.text_submitted.connect(_generate_seed)
		$Root/SeedPanel/Padding/Content/Row/Generate.pressed.connect(_generate_seed)
		seed_input.text_changed.connect(func(_text: String): seed_status.text = "")


func _process(_delta: float) -> void:
	if not generate_level.is_valid():
		return
	var current_seed := int(get_parent().get("random_seed"))
	if current_seed != last_seed:
		last_seed = current_seed
		seed_input.text = str(current_seed)
		seed_status.text = ""


func _generate_seed(_submitted_text: String = "") -> void:
	var text := seed_input.text.strip_edges()
	if not _valid_seed(text):
		seed_status.text = "Enter a whole number within the signed 64-bit range."
		seed_status.add_theme_color_override("font_color", Color("ef8b83"))
		seed_input.grab_focus()
		seed_input.select_all()
		return
	var seed_value := text.to_int()
	generate_level.call(seed_value)
	last_seed = seed_value
	seed_input.text = str(seed_value)
	seed_input.release_focus()
	seed_status.text = "Generated seed %d." % seed_value
	seed_status.add_theme_color_override("font_color", Color("a5d69e"))


func _valid_seed(text: String) -> bool:
	if not text.is_valid_int():
		return false
	var digits := text.trim_prefix("-").trim_prefix("+")
	while digits.length() > 1 and digits.begins_with("0"):
		digits = digits.substr(1)
	var limit := "9223372036854775808" if text.begins_with("-") else "9223372036854775807"
	return digits.length() < limit.length() or (digits.length() == limit.length() and digits <= limit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_return_to_menu()


func _return_to_menu() -> void:
	if transitioning:
		return
	transitioning = true
	get_tree().paused = false
	if get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn") != OK:
		transitioning = false
		push_error("Could not return to the main menu.")
