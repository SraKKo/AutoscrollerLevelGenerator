extends Node

const MAX_VOICES := 24
const STREAMS := {
	&"jump": preload("res://Assets/Sounds/player/Stone Jump.wav"),
	&"land": preload("res://Assets/Sounds/player/Stone Land.wav"),
	&"slide": preload("res://Assets/Sounds/player/slide.wav"),
	&"hurt": preload("res://Assets/Sounds/player/player_hurt.wav"),
	&"hit_1": preload("res://Assets/Sounds/player/Sword Impact Hit 1.wav"),
	&"hit_3": preload("res://Assets/Sounds/player/Sword Impact Hit 3.wav"),
	&"block": preload("res://Assets/Sounds/player/Sword Blocked 1.wav"),
	&"gem": preload("res://Assets/Sounds/player/gem_collect.wav"),
	&"coin": preload("res://Assets/Sounds/enemies/coins_gather_quick.wav"),
	&"enemy_attack": preload("res://Assets/Sounds/enemies/melee_attack.wav"),
	&"enemy_death": preload("res://Assets/Sounds/enemies/death.wav"),
	&"fireball": preload("res://Assets/Sounds/enemies/Fireball 2.wav"),
}
const VOLUME_DB := {
	&"jump": -8.0, &"land": -12.0, &"slide": -8.0, &"hurt": -4.0,
	&"hit_1": -8.0, &"hit_3": -8.0, &"block": -6.0, &"gem": -6.0,
	&"coin": -10.0, &"enemy_attack": -10.0, &"enemy_death": -8.0, &"fireball": -6.0,
}

var voices: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func play_effect(sound: StringName, source: Node2D = null) -> Node:
	if not STREAMS.has(sound):
		return null
	var camera := get_viewport().get_camera_2d()
	var half_size := get_viewport().get_visible_rect().size * 0.5
	if source != null and camera != null:
		half_size /= camera.zoom
		var offset := source.global_position - camera.get_screen_center_position()
		if absf(offset.x) > half_size.x + 192.0 or absf(offset.y) > half_size.y + 192.0:
			return null
	while voices.size() >= MAX_VOICES:
		stop_effect(voices[0])
	var voice
	if source != null:
		voice = AudioStreamPlayer2D.new()
		voice.max_distance = maxf(half_size.x, half_size.y) + 384.0
		voice.attenuation = 0.7
		voice.panning_strength = 0.5
	else:
		voice = AudioStreamPlayer.new()
	voice.name = "SFX_" + str(sound)
	voice.stream = STREAMS[sound]
	voice.bus = &"Effects"
	voice.volume_db = float(VOLUME_DB.get(sound, -8.0))
	add_child(voice)
	if source != null:
		voice.global_position = source.global_position
	voices.append(voice)
	voice.finished.connect(_finish_voice.bind(voice))
	voice.play()
	return voice


func play_sword_hit() -> void:
	play_effect(&"hit_1" if randi_range(0, 1) == 0 else &"hit_3")


func stop_effect(voice: Node) -> void:
	if not is_instance_valid(voice):
		voices.erase(voice)
		return
	voice.call("stop")
	_finish_voice(voice)


func stop_all() -> void:
	for voice in voices.duplicate():
		stop_effect(voice)


func _finish_voice(voice: Node) -> void:
	voices.erase(voice)
	if is_instance_valid(voice) and not voice.is_queued_for_deletion():
		voice.queue_free()
