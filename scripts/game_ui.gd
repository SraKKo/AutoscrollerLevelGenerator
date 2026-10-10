extends CanvasLayer

@export var player_path: NodePath

var player: PlayerController

@onready var health_sprite: AnimatedSprite2D = $Root/Health/AnimatedSprite2D
@onready var health_value: Label = get_node_or_null("Root/Health/HealthValue") as Label
@onready var coin_value: Label = $Root/Coins/CoinValue


func _ready() -> void:
	var target := get_node_or_null(player_path) if not player_path.is_empty() else null
	if target is PlayerController:
		bind_player(target)
	else:
		for candidate in get_tree().get_nodes_in_group(&"player"):
			if candidate is PlayerController:
				bind_player(candidate)
				break


func bind_player(target: PlayerController) -> void:
	if is_instance_valid(player) and player.health_changed.is_connected(_update_health):
		player.health_changed.disconnect(_update_health)
	if is_instance_valid(player) and player.coins_changed.is_connected(_update_coins):
		player.coins_changed.disconnect(_update_coins)
	player = target
	if is_instance_valid(player):
		player.health_changed.connect(_update_health)
		player.coins_changed.connect(_update_coins)
		_update_health(player.health, player.max_health)
		_update_coins(player.coins)


func _update_coins(total_coins: int) -> void:
	coin_value.text = str(total_coins)


func _update_health(current_health: int, maximum_health: int) -> void:
	if health_value != null:
		health_value.text = "%d / %d" % [current_health, maximum_health]
	var animation_name := StringName("hp_%d" % current_health)
	if health_sprite.sprite_frames != null and health_sprite.sprite_frames.has_animation(animation_name):
		health_sprite.animation = animation_name
		if health_sprite.sprite_frames.get_frame_count(animation_name) > 0:
			health_sprite.play()
