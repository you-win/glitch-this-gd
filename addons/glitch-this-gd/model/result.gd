extends Reference

var value
var error

func _init(p_value, p_error = null) -> void:
	value = p_value
	error = p_error

func is_ok() -> bool:
	return not is_err()

func is_err() -> bool:
	return error != null

func expect(text: String):
	if is_err():
		printerr(text)
		assert(false)
		return null
	return value

func or_else(val):
	return value if is_ok() else val
