class_name ChunkRoomsRenderer
extends Node2D

const CHUNK_TEXTURES := {
	"Start": preload("res://Assets/Chunks/Seamless/Start.png"),
	"Finish": preload("res://Assets/Chunks/Seamless/Finish.png"),
	"StraightRoom": preload("res://Assets/Chunks/Seamless/StraightRoom.png"),
	"StraightUpper": preload("res://Assets/Chunks/Seamless/StraightUpper.png"),
	"StraightLower": preload("res://Assets/Chunks/Seamless/StraightLower.png"),
	"GoingUp": preload("res://Assets/Chunks/Seamless/GoingUp.png"),
	"GoingDown": preload("res://Assets/Chunks/Seamless/GoingDown.png"),
	"RiseToUpper": preload("res://Assets/Chunks/Seamless/RiseToUpper.png"),
	"DropToLower": preload("res://Assets/Chunks/Seamless/DropToLower.png"),
	"UpperToMiddle": preload("res://Assets/Chunks/Seamless/UpperToMiddle.png"),
	"LowerToMiddle": preload("res://Assets/Chunks/Seamless/LowerToMiddle.png"),
	"SplitRoom": preload("res://Assets/Chunks/Seamless/SplitRoom.png"),
	"DoubleStraight": preload("res://Assets/Chunks/Seamless/DoubleStraight.png"),
	"KeepUpper": preload("res://Assets/Chunks/Seamless/KeepUpper.png"),
	"KeepLower": preload("res://Assets/Chunks/Seamless/KeepLower.png"),
	"DeadEnd": preload("res://Assets/Chunks/Seamless/DeadEnd.png"),
	"DeadEndUpper": preload("res://Assets/Chunks/Seamless/DeadEndUpper.png"),
	"DeadEndLower": preload("res://Assets/Chunks/Seamless/DeadEndLower.png"),
	"BranchUpper": preload("res://Assets/Chunks/Seamless/BranchUpper.png"),
	"BranchLower": preload("res://Assets/Chunks/Seamless/BranchLower.png"),
	"TripleSplit": preload("res://Assets/Chunks/Seamless/TripleSplit.png"),
	"SplitFromUpper": preload("res://Assets/Chunks/Seamless/SplitFromUpper.png"),
	"SplitFromLower": preload("res://Assets/Chunks/Seamless/SplitFromLower.png"),
	"UpperMiddleStraight": preload("res://Assets/Chunks/Seamless/UpperMiddleStraight.png"),
	"MiddleLowerStraight": preload("res://Assets/Chunks/Seamless/MiddleLowerStraight.png"),
	"TripleStraight": preload("res://Assets/Chunks/Seamless/TripleStraight.png"),
	"SplitUpperKeepLower": preload("res://Assets/Chunks/Seamless/SplitUpperKeepLower.png"),
	"SplitLowerKeepUpper": preload("res://Assets/Chunks/Seamless/SplitLowerKeepUpper.png"),
	"BranchDownKeepUpper": preload("res://Assets/Chunks/Seamless/BranchDownKeepUpper.png"),
	"BranchUpKeepLower": preload("res://Assets/Chunks/Seamless/BranchUpKeepLower.png"),
	"CloseUpperKeepMiddle": preload("res://Assets/Chunks/Seamless/CloseUpperKeepMiddle.png"),
	"CloseMiddleKeepUpper": preload("res://Assets/Chunks/Seamless/CloseMiddleKeepUpper.png"),
	"CloseLowerKeepMiddle": preload("res://Assets/Chunks/Seamless/CloseLowerKeepMiddle.png"),
	"CloseMiddleKeepLower": preload("res://Assets/Chunks/Seamless/CloseMiddleKeepLower.png"),
	"TripleCloseUpper": preload("res://Assets/Chunks/Seamless/TripleCloseUpper.png"),
	"TripleCloseMiddle": preload("res://Assets/Chunks/Seamless/TripleCloseMiddle.png"),
	"TripleCloseLower": preload("res://Assets/Chunks/Seamless/TripleCloseLower.png"),
	"TripleKeepUpper": preload("res://Assets/Chunks/Seamless/TripleKeepUpper.png"),
	"TripleKeepMiddle": preload("res://Assets/Chunks/Seamless/TripleKeepMiddle.png"),
	"TripleKeepLower": preload("res://Assets/Chunks/Seamless/TripleKeepLower.png"),
	"CrossX": preload("res://Assets/Chunks/Seamless/CrossX.png"),
	"CrossUpperMiddle": preload("res://Assets/Chunks/Seamless/CrossUpperMiddle.png"),
	"CrossMiddleLower": preload("res://Assets/Chunks/Seamless/CrossMiddleLower.png"),
	"CrossTriple": preload("res://Assets/Chunks/Seamless/CrossTriple.png"),
	"MergeRoom": preload("res://Assets/Chunks/Seamless/MergeRoom.png"),
	"MergeUpperMiddle": preload("res://Assets/Chunks/Seamless/MergeUpperMiddle.png"),
	"MergeMiddleLower": preload("res://Assets/Chunks/Seamless/MergeMiddleLower.png"),
	"ZigZagUp": preload("res://Assets/Chunks/Seamless/ZigZagUp.png"),
	"ZigZagDown": preload("res://Assets/Chunks/Seamless/ZigZagDown.png"),
}

const CHUNK_PIXEL_SIZE := Vector2(1088.0, 816.0)

@export var room_scale := Vector2.ONE

func rebuild(render_chunks: Array) -> Array[Vector2]:
	_clear_rooms()
	var room_positions: Array[Vector2] = []

	for chunk_data in render_chunks:
		var room: Dictionary = chunk_data as Dictionary
		var chunk_name: String = str(room["chunk_name"])
		var sprite := Sprite2D.new()
		sprite.name = "Chunk_%s" % chunk_name
		sprite.texture = CHUNK_TEXTURES[chunk_name] as Texture2D
		sprite.position = room["world_position"] as Vector2
		sprite.scale = room_scale
		add_child(sprite)
		room_positions.append(sprite.position)

	return room_positions

func get_scaled_room_size() -> Vector2:
	return CHUNK_PIXEL_SIZE * room_scale

func _clear_rooms() -> void:
	for child in get_children():
		child.queue_free()
