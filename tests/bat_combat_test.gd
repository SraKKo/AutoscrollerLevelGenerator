extends SceneTree

const PLAYER = preload("res://scenes/player.tscn")
const BAT = preload("res://scenes/Enemies/Bat.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var camera := Camera2D.new()
	camera.name = "AutoscrollCamera"
	world.add_child(camera)
	var player = PLAYER.instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.air_sweep_available = false
	var bat = BAT.instantiate()
	bat.position = Vector2(40, -8)
	world.add_child(bat)
	await physics_frame
	await physics_frame
	assert(bat.position == Vector2(40, -8), "Bat must stay in place")
	assert(bat.animated_sprite.animation == &"idle")
	player.action_locked = true
	player.animated_sprite.play(&"attack_1")
	player.animated_sprite.pause()
	player.animated_sprite.frame = 0
	player._update_attack_hitbox()
	assert(not bat.is_dead, "Wind-up must not hit")
	player.animated_sprite.frame = 2
	player._update_attack_hitbox()
	assert(bat.is_dead, "Normal attack must kill")
	assert(not player.air_sweep_available, "Normal attack must not refresh air slash")
	assert(bat.animated_sprite.animation == &"death")
	assert(not bat.receive_hit(), "Death must only register once")
	var air_bat = BAT.instantiate()
	air_bat.position = Vector2(-40, -24)
	world.add_child(air_bat)
	await physics_frame
	await physics_frame
	player.animated_sprite.flip_h = true
	player.animated_sprite.play(&"air_sweep")
	player.animated_sprite.pause()
	player.animated_sprite.frame = 2
	player._update_attack_hitbox()
	assert(air_bat.is_dead, "Air slash must hit in the facing direction")
	assert(player.air_sweep_available, "Air slash kill must refresh air slash")
	player.air_sweep_available = false
	player._update_attack_hitbox()
	assert(not player.air_sweep_available, "Dead enemy must not refresh again")
	await create_timer(0.7).timeout
	assert(not is_instance_valid(bat), "Bat must disappear after death animation")
	assert(not is_instance_valid(air_bat))
	print("PASS: bat idle, attack windows, facing, death, air slash refresh")
	world.queue_free()
	quit()
