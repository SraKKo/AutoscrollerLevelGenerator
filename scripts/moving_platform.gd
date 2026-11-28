extends AnimatableBody2D

@export var travel := Vector2(192, 0)
@export_range(32.0, 320.0, 8.0) var speed := 192.0


func _ready() -> void:
	if travel.is_zero_approx():
		return
	var dock := position
	var leg_duration := travel.length() / speed
	var cycle := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_loops()
	cycle.tween_interval(0.25)
	cycle.tween_property(self, "position", dock + travel, leg_duration)
	cycle.tween_interval(0.25)
	cycle.tween_property(self, "position", dock, leg_duration)
