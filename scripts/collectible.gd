extends Area2D

signal collected(player: PlayerController)

@export_range(1, 1000, 1) var coin_value := 1
@export_range(-1, 10000, 1) var score_value := -1
@export var pickup_sound: StringName = &"coin"

var is_collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_collected or not body is PlayerController or body.is_dead:
		return
	is_collected = true
	SFX.play_effect(pickup_sound)
	body.add_coins(coin_value, score_value)
	hide()
	collected.emit(body)
	queue_free()
