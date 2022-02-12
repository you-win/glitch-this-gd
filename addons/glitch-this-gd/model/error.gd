extends Reference

enum Code {
	NONE = 0,

	#region General

	UNRECOGNIZED_FILE_TYPE,
	FILE_NOT_FOUND,

	#endregion
	
	#region glitch_this
	
	GLITCH_THIS_NOT_SUPPORTED,
	GLITCH_THIS_UNABLE_TO_LOAD,
	GLITCH_THIS_UNABLE_TO_CREATE_FROM_DATA
	
	#endregion
}

var _error: int
var _description: String

func _init(error_code: int, error_description: String = "") -> void:
	_error = error_code
	_description = error_description

func error_code() -> int:
	return _error

func error_name() -> String:
	return Code.keys()[_error]

func has_description() -> bool:
	return not _description.empty()

func description() -> String:
	return _description
