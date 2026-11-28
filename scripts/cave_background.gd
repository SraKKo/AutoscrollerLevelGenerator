extends CanvasLayer


func _process(_delta: float) -> void:
	var viewport := get_viewport()
	var size := viewport.get_visible_rect().size
	var camera := viewport.get_camera_2d()
	var camera_x := camera.get_screen_center_position().x if camera else 0.0
	for sprite: Sprite2D in get_children():
		var texture_size := sprite.texture.get_size()
		var fit := maxf(size.x / texture_size.x, size.y / texture_size.y)
		if fit <= 0.0:
			continue
		var factor := float(sprite.get_meta("scroll_factor"))
		var offset := fposmod(camera_x * factor / fit, texture_size.x)
		sprite.scale = Vector2.ONE * fit
		sprite.region_rect = Rect2(Vector2(offset, 0), size / fit)
