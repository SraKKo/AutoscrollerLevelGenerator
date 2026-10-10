extends "res://scripts/collectible.gd"

const GEM_TEXTURES: Array[Texture2D] = [
	preload("res://Assets/Interactable/Gem1.png"),
	preload("res://Assets/Interactable/Gem2.png"),
	preload("res://Assets/Interactable/gem3.png"),
]

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	sprite.texture = GEM_TEXTURES.pick_random()
	super._ready()
