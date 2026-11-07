class_name ChunkPortContracts
extends RefCounted

const NONE := 0
const UPPER := 1
const MIDDLE := 2
const LOWER := 4
const ALL := UPPER | MIDDLE | LOWER

const LEFT_EDGE_COLUMN := -34
const RIGHT_EDGE_COLUMN := 33
const LANE_ROWS: Array[int] = [-14, 4, 20]
const LANE_BITS: Array[int] = [UPPER, MIDDLE, LOWER]

# Vector2i stores the left mask in x and the right mask in y.
const CONTRACTS: Dictionary = {
	"Start": Vector2i(NONE, MIDDLE),
	"Finish": Vector2i(MIDDLE, NONE),
	"StraightRoom": Vector2i(MIDDLE, MIDDLE),
	"StraightUpper": Vector2i(UPPER, UPPER),
	"StraightLower": Vector2i(LOWER, LOWER),
	"GoingUp": Vector2i(LOWER, UPPER),
	"GoingDown": Vector2i(UPPER, LOWER),
	"RiseToUpper": Vector2i(MIDDLE, UPPER),
	"DropToLower": Vector2i(MIDDLE, LOWER),
	"UpperToMiddle": Vector2i(UPPER, MIDDLE),
	"LowerToMiddle": Vector2i(LOWER, MIDDLE),
	"SplitRoom": Vector2i(MIDDLE, UPPER | LOWER),
	"DoubleStraight": Vector2i(UPPER | LOWER, UPPER | LOWER),
	"KeepUpper": Vector2i(UPPER | LOWER, UPPER),
	"KeepLower": Vector2i(UPPER | LOWER, LOWER),
	"DeadEnd": Vector2i(MIDDLE, NONE),
	"DeadEndUpper": Vector2i(UPPER, NONE),
	"DeadEndLower": Vector2i(LOWER, NONE),
	"BranchUpper": Vector2i(MIDDLE, UPPER | MIDDLE),
	"BranchLower": Vector2i(MIDDLE, MIDDLE | LOWER),
	"TripleSplit": Vector2i(MIDDLE, ALL),
	"SplitFromUpper": Vector2i(UPPER, UPPER | MIDDLE),
	"SplitFromLower": Vector2i(LOWER, MIDDLE | LOWER),
	"UpperMiddleStraight": Vector2i(UPPER | MIDDLE, UPPER | MIDDLE),
	"MiddleLowerStraight": Vector2i(MIDDLE | LOWER, MIDDLE | LOWER),
	"TripleStraight": Vector2i(ALL, ALL),
	"SplitUpperKeepLower": Vector2i(UPPER | LOWER, ALL),
	"SplitLowerKeepUpper": Vector2i(UPPER | LOWER, ALL),
	"BranchDownKeepUpper": Vector2i(UPPER | MIDDLE, ALL),
	"BranchUpKeepLower": Vector2i(MIDDLE | LOWER, ALL),
	"CloseUpperKeepMiddle": Vector2i(UPPER | MIDDLE, MIDDLE),
	"CloseMiddleKeepUpper": Vector2i(UPPER | MIDDLE, UPPER),
	"CloseLowerKeepMiddle": Vector2i(MIDDLE | LOWER, MIDDLE),
	"CloseMiddleKeepLower": Vector2i(MIDDLE | LOWER, LOWER),
	"TripleCloseUpper": Vector2i(ALL, MIDDLE | LOWER),
	"TripleCloseMiddle": Vector2i(ALL, UPPER | LOWER),
	"TripleCloseLower": Vector2i(ALL, UPPER | MIDDLE),
	"TripleKeepUpper": Vector2i(ALL, UPPER),
	"TripleKeepMiddle": Vector2i(ALL, MIDDLE),
	"TripleKeepLower": Vector2i(ALL, LOWER),
	"CrossX": Vector2i(UPPER | LOWER, UPPER | LOWER),
	"CrossUpperMiddle": Vector2i(UPPER | MIDDLE, UPPER | MIDDLE),
	"CrossMiddleLower": Vector2i(MIDDLE | LOWER, MIDDLE | LOWER),
	"CrossTriple": Vector2i(ALL, ALL),
	"MergeRoom": Vector2i(UPPER | LOWER, MIDDLE),
	"MergeUpperMiddle": Vector2i(UPPER | MIDDLE, MIDDLE),
	"MergeMiddleLower": Vector2i(MIDDLE | LOWER, MIDDLE),
	"ZigZagUp": Vector2i(MIDDLE, MIDDLE),
	"ZigZagDown": Vector2i(MIDDLE, MIDDLE),
}

const RUNTIME_TYPES: Array[String] = [
	"Start",
	"Finish",
	"StraightRoom",
	"ZigZagUp",
	"ZigZagDown",
	"TripleSplit",
	"CrossTriple",
	"TripleStraight",
	"TripleCloseUpper",
	"TripleCloseMiddle",
	"TripleCloseLower",
	"DoubleStraight",
	"CrossX",
	"MergeRoom",
	"UpperMiddleStraight",
	"CrossUpperMiddle",
	"MergeUpperMiddle",
	"MiddleLowerStraight",
	"CrossMiddleLower",
	"MergeMiddleLower",
]


static func has_contract(chunk_type: String) -> bool:
	return CONTRACTS.has(chunk_type)


static func masks_for(chunk_type: String) -> Vector2i:
	if not CONTRACTS.has(chunk_type):
		return Vector2i(-1, -1)
	var masks: Vector2i = CONTRACTS[chunk_type]
	return masks


static func first_sequence_error(chunk_types: Array[String]) -> String:
	if chunk_types.is_empty():
		return "Sekwencja chunkow jest pusta."

	for chunk_type: String in chunk_types:
		if not has_contract(chunk_type):
			return "Brak kontraktu portow dla chunka %s." % chunk_type

	for index: int in range(chunk_types.size() - 1):
		var current_type: String = chunk_types[index]
		var next_type: String = chunk_types[index + 1]
		var current_masks: Vector2i = masks_for(current_type)
		var next_masks: Vector2i = masks_for(next_type)
		if current_masks.y != next_masks.x:
			return "%s (%s) nie pasuje do %s (%s) na pozycji %d." % [
				current_type,
				describe_mask(current_masks.y),
				next_type,
				describe_mask(next_masks.x),
				index,
			]
	return ""


static func detect_edge_mask(ground: TileMapLayer, column: int) -> int:
	var mask := NONE
	for index: int in range(LANE_ROWS.size()):
		var row: int = LANE_ROWS[index]
		var cell := Vector2i(column, row)
		var has_surface: bool = (
			ground.get_cell_source_id(cell) != -1
			and ground.get_cell_source_id(cell + Vector2i.UP) == -1
		)
		if has_surface:
			mask |= LANE_BITS[index]
	return mask


static func validate_ground_edges(ground: TileMapLayer, chunk_type: String) -> String:
	if not has_contract(chunk_type):
		return "Brak kontraktu portow dla chunka %s." % chunk_type
	var expected: Vector2i = masks_for(chunk_type)
	var actual := Vector2i(
		detect_edge_mask(ground, LEFT_EDGE_COLUMN),
		detect_edge_mask(ground, RIGHT_EDGE_COLUMN)
	)
	if actual == expected:
		return ""
	return "%s ma porty L=%s R=%s, oczekiwano L=%s R=%s." % [
		chunk_type,
		describe_mask(actual.x),
		describe_mask(actual.y),
		describe_mask(expected.x),
		describe_mask(expected.y),
	]


static func describe_mask(mask: int) -> String:
	if mask == NONE:
		return "none"
	var names: Array[String] = []
	if mask & UPPER:
		names.append("upper")
	if mask & MIDDLE:
		names.append("middle")
	if mask & LOWER:
		names.append("lower")
	return "+".join(names)
