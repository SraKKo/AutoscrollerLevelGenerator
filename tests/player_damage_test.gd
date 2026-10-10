extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	assert(player.health == 3)
	player.action_locked = true
	player.animated_sprite.play(&"attack_1")
	assert(player.take_damage(1, Vector2(-10, 0)))
	assert(player.health == 2 and not player.is_dead)
	assert(player.animated_sprite.animation == &"hurt", "Hit must interrupt attack")
	assert(player.velocity.x > 0 and player.velocity.y < 0, "Knockback must push away and up")
	assert(player.hurt_material.get_shader_parameter("invulnerable"))
	assert(not player.take_damage(1, Vector2(-10, 0)), "Repeated contact must be blocked")
	assert(player.health == 2)
	await create_timer(1.1).timeout
	assert(not player.hurt_material.get_shader_parameter("invulnerable"), "Blink must end")
	assert(player.take_damage(1, Vector2(10, 0)))
	assert(player.health == 1 and player.velocity.x < 0)
	await create_timer(1.1).timeout
	assert(player.take_damage(1, Vector2(10, 0)))
	assert(player.health == 0 and player.is_dead, "Third hit must kill")
	player.reset_to_spawn()
	assert(player.health == 3 and not player.is_dead and player.invulnerability_timer.is_stopped())
	assert(player.take_damage(1, Vector2(-10, 0)))
	var saw = load("res://scenes/Traps/SawTrap.tscn").instantiate()
	world.add_child(saw)
	saw.set_physics_process(false)
	saw.sprite.play(&"active")
	saw.sprite.pause()
	player.position = saw.hitbox.global_position
	await create_timer(0.08).timeout
	saw._physics_process(0.0)
	assert(player.is_dead, "Saw must bypass invulnerability")
	player.reset_to_spawn()
	player.position = Vector2(30, 0)
	var melee = load("res://scenes/Enemies/GoblinMelee.tscn").instantiate()
	world.add_child(melee)
	melee.set_physics_process(false)
	melee.player = player
	await create_timer(0.08).timeout
	melee._choose_action()
	assert(melee.state == melee.State.RECOVERY and player.health == 2, "Melee must hit immediately on entering range")
	var second_player = load("res://scenes/player.tscn").instantiate()
	world.add_child(second_player)
	second_player.set_physics_process(false)
	assert(not second_player.hurt_material.get_shader_parameter("invulnerable"), "Shader state must be per player")
	print("PASS: 3 HP, invulnerability, blink state, knockback, reset, instant melee, lethal saw")
	world.queue_free()
	quit()
