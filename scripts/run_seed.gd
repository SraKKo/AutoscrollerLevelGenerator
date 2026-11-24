extends RefCounted

# One-shot override passed from the main menu to the first stage.
static var pending: Variant = null


static func is_valid(text: String) -> bool:
	if not text.is_valid_int():
		return false
	var digits := text.trim_prefix("-").trim_prefix("+").lstrip("0")
	var limit := "9223372036854775808" if text.begins_with("-") else "9223372036854775807"
	return digits.length() < limit.length() or (digits.length() == limit.length() and digits <= limit)
