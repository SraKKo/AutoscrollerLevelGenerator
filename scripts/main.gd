extends Node2D

const ProceduralLevelGeneratorScript := preload("res://scripts/procedural_level_generator.gd")

@export var random_seed := 12345
@export var platform_count := 10

var generator := ProceduralLevelGeneratorScript.new()
var level: Dictionary = {}
var use_dfs := false

func _ready() -> void:
	_generate_level(random_seed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("generate_level"):
		_generate_level(int(Time.get_unix_time_from_system()))
	elif event.is_action_pressed("toggle_validation_method"):
		use_dfs = not use_dfs
		_revalidate_current_level()

func _generate_level(seed_value: int) -> void:
	random_seed = seed_value
	level = generator.generate(random_seed, platform_count)
	_revalidate_current_level()

func _revalidate_current_level() -> void:
	if level.is_empty():
		return

	var method: String = PlatformGraphValidator.METHOD_DFS if use_dfs else PlatformGraphValidator.METHOD_BFS
	level["validation"] = PlatformGraphValidator.validate_path(
		level["graph"],
		int(level["start_id"]),
		int(level["goal_id"]),
		method
	)
	queue_redraw()

func _draw() -> void:
	if level.is_empty():
		return

	_draw_background()
	_draw_graph()
	_draw_platforms()
	_draw_hud()

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("#111827"))

	for y in range(80, int(get_viewport_rect().size.y), 80):
		draw_line(Vector2(0, y), Vector2(get_viewport_rect().size.x, y), Color("#1f2937"), 1.0)

func _draw_graph() -> void:
	var platforms_by_id: Dictionary = {}
	for platform_data in level["platforms"]:
		var platform: Dictionary = platform_data as Dictionary
		platforms_by_id[platform["id"]] = platform

	for from_id in level["graph"]:
		for to_id in level["graph"][from_id]:
			var from_platform: Dictionary = platforms_by_id[from_id] as Dictionary
			var to_platform: Dictionary = platforms_by_id[to_id] as Dictionary
			draw_line(from_platform["center"] as Vector2, to_platform["center"] as Vector2, Color("#334155"), 2.0)

	var path: Array = level["validation"]["path"]
	for i in range(path.size() - 1):
		var from_platform: Dictionary = platforms_by_id[path[i]] as Dictionary
		var to_platform: Dictionary = platforms_by_id[path[i + 1]] as Dictionary
		draw_line(from_platform["center"] as Vector2, to_platform["center"] as Vector2, Color("#22c55e"), 5.0)

func _draw_platforms() -> void:
	for platform_data in level["platforms"]:
		var platform: Dictionary = platform_data as Dictionary
		var color: Color = Color("#38bdf8")
		if platform["type"] == "start":
			color = Color("#22c55e")
		elif platform["type"] == "goal":
			color = Color("#f59e0b")
		elif platform["type"] == "dead_end":
			color = Color("#ef4444")
		elif level["validation"]["visit_order"].has(platform["id"]):
			color = Color("#a78bfa")

		draw_rect(Rect2(platform["position"] as Vector2, platform["size"] as Vector2), color)
		draw_string(ThemeDB.fallback_font, (platform["position"] as Vector2) + Vector2(8, -8), str(platform["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _draw_hud() -> void:
	var method: String = "DFS" if use_dfs else "BFS"
	var status: String = "GRYWALNY" if bool(level["validation"]["playable"]) else "NIEGRYWALNY"
	var status_color: Color = Color("#22c55e") if bool(level["validation"]["playable"]) else Color("#ef4444")
	var lines: Array = [
		"Proceduralna generacja poziomu 2D + walidacja grywalnosci",
		"Seed: %s | Proby generatora: %s | Metoda: %s | Status: %s" % [level["seed"], level["attempts"], method, status],
		"R - nowy poziom, V - BFS/DFS",
		"Skoki poziome lub pod katem 45 stopni | Czerwone platformy: slepe zaulki",
		"Sciezka: %s" % [str(level["validation"]["path"])],
	]

	draw_rect(Rect2(24, 20, 860, 136), Color(0.02, 0.03, 0.05, 0.78))
	for i in range(lines.size()):
		var color: Color = status_color if i == 1 else Color.WHITE
		draw_string(ThemeDB.fallback_font, Vector2(40, 48 + i * 24), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
