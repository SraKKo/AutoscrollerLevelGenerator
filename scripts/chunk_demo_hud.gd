class_name ChunkDemoHud
extends CanvasLayer

@onready var info_label: Label = $Panel/Info

func update_level(level: Dictionary, use_dfs: bool) -> void:
	if level.is_empty():
		return

	var method: String = "DFS" if use_dfs else "BFS"
	var validation: Dictionary = level["validation"] as Dictionary
	var status: String = "GRYWALNY" if bool(validation["playable"]) else "NIEGRYWALNY"
	var lines := PackedStringArray([
		"Proceduralny poziom z nowych chunkow PNG",
		"Seed: %s | Metoda: %s | Status: %s | Slepe zaulki: %s" % [
			level["seed"], method, status, level["dead_end_count"],
		],
		"R - nowy uklad, V - BFS/DFS, WASD/strzalki - kamera, Q/E/kolko - zoom",
		"Y: wybrana sciezka | MAYBE: inna droga do mety | N: slepy zaulek",
	])
	info_label.text = "\n".join(lines)
