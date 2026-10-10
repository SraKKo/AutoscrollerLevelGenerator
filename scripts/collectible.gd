extends Area2D

signal collected(player: PlayerController)

@export_range(1, 1000, 1) var coin_value := 1

var is_collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_collected or not body is PlayerController or body.is_dead:
		return
	is_collected = true
	body.add_coins(coin_value)
	hide()
	collected.emit(body)
	queue_free()
