extends Control

@export_range(1, 8, 1) var minimum_digits := 4
@export_range(16, 64, 1) var digit_width := 24
@export_range(24, 96, 1) var digit_height := 44
@export_range(16, 64, 1) var font_size := 32
@export_range(0.05, 1.0, 0.01) var roll_duration := 0.24

var value := 0
var columns: Array[Dictionary] = []
var flash: Tween

@onready var digits: HBoxContainer = $Digits


func _ready() -> void:
	set_value(0, true)


func set_value(new_value: int, instant: bool = false) -> void:
	new_value = maxi(0, new_value)
	if new_value == value and not instant:
		return
	var text := str(new_value).pad_zeros(minimum_digits)
	if columns.size() != text.length():
		_rebuild_columns(text.length())
		var previous := str(value).pad_zeros(text.length())
		for i in range(columns.size()):
			_roll_digit(columns[i], int(previous[i]), true)
	for i in range(columns.size()):
		_roll_digit(columns[i], int(text[i]), instant)
	if instant:
		if flash != null: flash.kill()
		self_modulate = Color.WHITE
	elif new_value > value:
		if flash != null: flash.kill()
		self_modulate = Color(1.0, 0.85, 0.5)
		flash = create_tween()
		flash.tween_property(self, "self_modulate", Color.WHITE, 0.32)
	value = new_value


func _rebuild_columns(count: int) -> void:
	for column in columns:
		var tween: Tween = column["tween"]
		if tween != null: tween.kill()
	columns.clear()
	for child in digits.get_children():
		digits.remove_child(child)
		child.queue_free()
	for i in range(count):
		var window := Control.new()
		window.name = "Digit%d" % i
		window.custom_minimum_size = Vector2(digit_width, digit_height)
		window.clip_contents = true
		window.mouse_filter = Control.MOUSE_FILTER_IGNORE
		digits.add_child(window)
		var strip := Control.new()
		strip.name = "Reel"
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window.add_child(strip)
		# Two cycles plus a final zero allow continuous upward wraparound.
		for number in range(21):
			var label := Label.new()
			label.text = str(number % 10)
			label.position = Vector2(0, number * digit_height)
			label.size = Vector2(digit_width, digit_height)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", font_size)
			label.add_theme_color_override("font_color", Color("eee5cf"))
			label.add_theme_color_override("font_outline_color", Color("111821"))
			label.add_theme_constant_override("outline_size", 4)
			strip.add_child(label)
		columns.append({"strip": strip, "target": 0, "tween": null})


func _roll_digit(column: Dictionary, digit: int, instant: bool) -> void:
	if not instant and int(column["target"]) == digit:
		return
	var tween: Tween = column["tween"]
	if tween != null: tween.kill()
	var strip: Control = column["strip"]
	column["target"] = digit
	if instant:
		strip.position.y = -digit * digit_height
		column["tween"] = null
		return
	# Preserve the visible position if another coin arrives mid-animation.
	var phase := fposmod(-strip.position.y / float(digit_height), 10.0)
	strip.position.y = -phase * digit_height
	var destination := float(digit)
	if destination < phase:
		destination += 10.0
	tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	column["tween"] = tween
	tween.tween_property(strip, "position:y", -destination * digit_height, roll_duration)
	tween.tween_callback(func(): strip.position.y = -digit * digit_height)
