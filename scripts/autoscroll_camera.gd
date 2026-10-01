class_name AutoscrollCamera
extends Camera2D

@export_range(0.0, 1000.0, 10.0) var scroll_speed := 220.0
@export var scrolling := true


func _physics_process(delta: float) -> void:
	if scrolling:
		global_position.x += scroll_speed * delta


func reset_to(start_position: Vector2) -> void:
	global_position = start_position
	reset_smoothing()
