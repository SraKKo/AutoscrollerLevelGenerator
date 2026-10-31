extends CanvasLayer

signal retry_requested
signal new_run_requested
signal menu_requested


func _ready() -> void:
	%Retry.pressed.connect(func(): retry_requested.emit())
	%NewRun.pressed.connect(func(): new_run_requested.emit())
	%ReturnToMenu.pressed.connect(func(): menu_requested.emit())
	hide_result()


func show_result(final_score: int, coins: int, seconds: float, seed_value: int) -> void:
	%FinalScore.text = str(final_score)
	%RunStats.text = "Time  %02d:%02d   ·   Coins  %d" % [int(seconds) / 60, int(seconds) % 60, coins]
	%Seed.text = "Seed: %d" % seed_value
	$Root.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	%Retry.grab_focus()


func hide_result() -> void:
	$Root.hide()
