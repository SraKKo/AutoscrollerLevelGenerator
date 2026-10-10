extends Area2D

signal collected(player: PlayerController)

const GEM_TEXTURES: Array[Texture2D] = [
	preload("res://Assets/Interactable/Gem1.png"),
	preload("res://Assets/Interactable/Gem2.png"),
	preload("res://Assets/Interactable/gem3.png"),
]

var is_collected := false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	sprite.texture = GEM_TEXTURES.pick_random()
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_collected or not body is PlayerController or body.is_dead:
		return
	is_collected = true
	hide()
	collected.emit(body)
	queue_free()
