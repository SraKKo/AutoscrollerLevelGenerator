extends SceneTree

const PLAYER := preload("res://scenes/player.tscn")
const NAMES := ["GoblinMelee", "GoblinMage", "SmallMushroom", "BigMushroom"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var camera := Camera2D.new()
	world.add_child(camera)
	var ground := StaticBody2D.new()
	ground.collision_layer = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(240, 20)
	shape.shape = rect
	ground.position.y = 10
	ground.add_child(shape)
	world.add_child(ground)
	var player = PLAYER.instantiate()
	player.position = Vector2(100, 0)
	world.add_child(player)
	player.set_physics_process(false)
	for i in range(NAMES.size()):
		var enemy = load("res://scenes/Enemies/%s.tscn" % NAMES[i]).instantiate()
		enemy.position = Vector2(40, 0)
		world.add_child(enemy)
		await physics_frame
		await physics_frame
		enemy.set_physics_process(false)
		assert(enemy.sprite.sprite_frames.has_animation(&"death"))
		var hp: int = enemy.health
		player.position = Vector2(0, 0)
		player.action_locked = true
		player.animated_sprite.play(&"attack_1")
		player.animated_sprite.pause()
		player.animated_sprite.frame = 2
		player.attack_targets.clear()
		player._update_attack_hitbox()
		player._update_attack_hitbox()
		assert(enemy.health == hp - 1, "One swing must hit once")
		for hit in range(hp - 1):
			enemy.receive_hit()
		assert(enemy.is_dead)
		assert(not enemy.receive_hit())
		await create_timer(0.55).timeout
		assert(not is_instance_valid(enemy), "Death animation must remove enemy")
		player.position = Vector2(100, 0)
	var mage = load("res://scenes/Enemies/GoblinMage.tscn").instantiate()
	world.add_child(mage)
	await physics_frame
	await physics_frame
	mage.set_physics_process(false)
	mage.player = player
	var mage_origin: Vector2 = mage.global_position
	player.position = Vector2(100, -150)
	await physics_frame
	await physics_frame
	mage.state = mage.State.IDLE
	mage._choose_action()
	assert(mage.state == mage.State.WINDUP, "Circular range must detect player above mage")
	mage.state = mage.State.WINDUP
	mage._on_state_timeout()
	var projectile = world.get_child(world.get_child_count() - 1)
	assert(projectile.name.begins_with("MageProjectile"))
	var target_position: Vector2 = player.global_position + Vector2(0, -12)
	assert(projectile.global_position == target_position, "Charge must spawn on player")
	await create_timer(0.1).timeout
	assert(not player.is_dead and not projectile.exploding, "Warning must be harmless")
	player.position = Vector2(500, -400)
	await create_timer(0.08).timeout
	mage.timer.stop()
	mage.state = mage.State.IDLE
	mage._choose_action()
	assert(mage.state == mage.State.IDLE, "Outside circle must not trigger attack")
	assert(projectile.global_position == target_position, "Charge must stay at original position")
	await create_timer(0.75).timeout
	assert(projectile.exploding and not player.is_dead, "Leaving blast radius must avoid damage")
	await create_timer(0.25).timeout
	assert(not is_instance_valid(projectile), "Explosion must clean up")
	assert(mage.global_position == mage_origin, "Mage must remain stationary")
	player.position = Vector2(100, 0)
	await create_timer(0.08).timeout
	mage.state = mage.State.WINDUP
	mage._on_state_timeout()
	projectile = world.get_child(world.get_child_count() - 1)
	assert(projectile.name.begins_with("MageProjectile"))
	await create_timer(0.1).timeout
	assert(not player.is_dead)
	await create_timer(0.75).timeout
	assert(player.health == 2 and not player.is_dead, "Blast must deal only one damage during invulnerability")
	await create_timer(0.25).timeout
	player.reset_to_spawn()
	player.position = Vector2(100, 0)
	mage.queue_free()
	var big = load("res://scenes/Enemies/BigMushroom.tscn").instantiate()
	world.add_child(big)
	big.set_physics_process(false)
	big.player = player
	assert(big.detection_range == 320.0 and big.windup_time == 0.0)
	player.position = Vector2(30, 0)
	await create_timer(0.08).timeout
	big._choose_action()
	assert(big.state == big.State.RECOVERY and player.health == 2, "Nearby player must be hit immediately")
	big.queue_free()
	player.position = Vector2(100, -100)
	var small = load("res://scenes/Enemies/SmallMushroom.tscn").instantiate()
	small.position = Vector2(100, 0)
	world.add_child(small)
	await physics_frame
	await physics_frame
	small.set_physics_process(false)
	small.position = Vector2(110, 0)
	small.velocity = Vector2(0, 10)
	small.move_and_slide()
	small.facing = 1.0
	small._choose_action()
	assert(small.velocity.x == 0.0 and small.facing == -1.0, "Must turn at ledge")
	var far = load("res://scenes/Enemies/GoblinMelee.tscn").instantiate()
	far.position = Vector2(2000, 0)
	world.add_child(far)
	await physics_frame
	await physics_frame
	assert(not far.active, "Offscreen enemy must sleep")
	camera.position.x = 4000
	camera.reset_smoothing()
	await physics_frame
	await physics_frame
	await process_frame
	assert(not is_instance_valid(far), "Enemy behind camera must despawn")
	print("PASS: enemy combat, circular mage range, stationary delayed blast, dodge, big mushroom reaction, ledges, autoscroll")
	world.queue_free()
	quit()
