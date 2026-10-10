extends SceneTree

const PLAYER = preload("res://scenes/player.tscn")
const ARROW = preload("res://scenes/Traps/Arrow.tscn")


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
	for scene_name in ["SawTrap", "CeilingTrap"]:
		var trap = load("res://scenes/Traps/%s.tscn" % scene_name).instantiate()
		world.add_child(trap)
		trap.set_physics_process(false)
		trap.sprite.pause()
		player.reset_to_spawn()
		player.position = Vector2(64, 100)
		await physics_frame
		await physics_frame
		trap.set_physics_process(true)
		assert(not player.is_dead, "Activation must be harmless")
		trap.sprite.play(&"active")
		trap.sprite.pause()
		if scene_name == "CeilingTrap":
			trap.sprite.frame = 0
			await physics_frame
			await physics_frame
			assert(not player.is_dead, "Raised ceiling must allow passage underneath")
			trap.sprite.frame = 2
		else:
			player.position = trap.hitbox.global_position
		await create_timer(0.08).timeout
		await physics_frame
		await physics_frame
		await physics_frame
		if scene_name == "SawTrap":
			assert(player.is_dead and player.health == 0, "Saw must kill from full health")
			assert(player.animated_sprite.animation == &"death")
		else:
			assert(not player.is_dead and player.health == 2, "Ceiling trap must deal one damage")
		trap.queue_free()
		await process_frame
	player.reset_to_spawn()
	player.position = Vector2(64, 42)
	var launcher = load("res://scenes/Traps/ArrowTrap.tscn").instantiate()
	launcher.position = Vector2(200, 0)
	world.add_child(launcher)
	launcher.sprite.pause()
	launcher.sprite.frame = 8
	await create_timer(0.6).timeout
	assert(not player.is_dead and player.health == 2, "Launched arrow must deal one damage")
	launcher.queue_free()
	await process_frame
	player.reset_to_spawn()
	player.position = Vector2.ZERO
	var wall := StaticBody2D.new()
	wall.position = Vector2(100, 0)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(10, 100)
	shape.shape = rectangle
	wall.add_child(shape)
	world.add_child(wall)
	var arrow = ARROW.instantiate()
	arrow.position = Vector2(200, 0)
	world.add_child(arrow)
	await create_timer(0.6).timeout
	assert(not is_instance_valid(arrow), "Wall must remove arrow")
	assert(not player.is_dead, "Wall must protect player")
	print("PASS: trap activation, saw contact, ceiling movement, arrow launch, wall blocking")
	world.queue_free()
	quit()
