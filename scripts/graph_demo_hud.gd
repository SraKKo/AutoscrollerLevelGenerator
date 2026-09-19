class_name GraphDemoHud
extends CanvasLayer

@onready var info_label: Label = $Panel/Info

func update_level(level: Dictionary, use_dfs: bool) -> void:
	var validation: Dictionary = level["validation"] as Dictionary
	var method: String = "DFS" if use_dfs else "BFS"
	var status: String = "GRYWALNY" if bool(validation["playable"]) else "NIEGRYWALNY"
	var lines := PackedStringArray([
		"Proceduralny graf poziomu - bez chunkow PNG",
		"Seed: %s | Metoda: %s | Status: %s | Rozwidlenia: %s" % [
			level["seed"], method, status, level["dead_end_count"],
		],
		"Y: wybrana trasa | M: inna droga do mety | N: slepy zaulek",
		"R - nowy graf, V - BFS/DFS, WASD/strzalki - kamera, Q/E/kolko - zoom",
	])
	info_label.text = "\n".join(lines)
