extends Reference

const Result = preload("res://addons/glitch-this-gd/model/result.gd")
const Error = preload("res://addons/glitch-this-gd/model/error.gd")

enum ImageMode {
	NONE = 0,
	UNKNOWN
}

const VERSION := "1.0.2"

var logger: Reference = load("res://addons/glitch-this-gd/logger.gd").new()

var rng := RandomNumberGenerator.new()
var random_seed: int
var has_seed := false

# Setting up global variables needed for glitching
var pixel_tuple_len: int = 0
var img_size := Vector2.ZERO
var img_mode: int = ImageMode.UNKNOWN

# Creating 3D arrays for pixel data
var input_arr: PoolByteArray
var output_arr: PoolByteArray

# Getting PATH of temp folders
var gif_dir_path: String

# Setting glitch_amount max and min
var glitch_max: float = 10.0
var glitch_min: float = 0.1

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _init() -> void:
	logger.setup(self)

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

func _is_gif(img) -> bool:
	logger.error("_is_gif not yet implemented")
	
	return false

func _reset_rng_seed(offset: int = 0) -> void:
	"""
	The Godot api for `random` is slightly different but this should still be correct
	"""
	rng.seed = random_seed + offset

func _get_random_channel() -> int:
	return rng.randi_range(0, pixel_tuple_len - 1)

#region File system access

func _open_image(path: String) -> Result:
	path = path.to_lower()
	
	if path.ends_with(".gif"):
		# TODO not yet implemented
		return Result.new(null, Error.new(Error.Error.GLITCH_THIS_NOT_SUPPORTED, ".gif not yet implemented"))
	elif path.ends_with(".png"):
		var image := Image.new()
		if image.load(path) != OK:
			logger.error("Unable to load png at path %s" % path)
			return Result.new(null, Error.new(Error.Code.GLITCH_THIS_UNABLE_TO_LOAD, "Unable to open image"))
		image.convert(Image.FORMAT_RGBA8)
		return Result.new(image)
	else:
		logger.error("Unrecognized path %s" % path)
		return Result.new(null, Error.new(Error.Code.UNRECOGNIZED_FILE_TYPE, "Unable to open image"))

func _fetch_image(src_img, gif_allowed: bool) -> Result:
	if typeof(src_img) == TYPE_STRING  and (gif_allowed or not src_img.to_lower().ends_with(".gif")):
		return _open_image(src_img)
	elif src_img is Image and (gif_allowed or not _is_gif(src_img)):
		# TODO implement gif handling
		# TODO implement magic bits checking
		# Right now just assume everything is a png
		
		var img := Image.new()
		img.copy_from(src_img)
		
		img.convert(Image.FORMAT_RGBA8)
		
		return Result.new(img)
	else:
		return Result.new(null, Error.new(Error.Code.GLITCH_THIS_NOT_SUPPORTED, "Unable to fetch image"))

#endregion

#region Glitching

func _change_glitch(glitch_amount: float, glitch_change: float, cycle: bool) -> float:
	"""
	Changes glitch amount by given increment/decrement
	"""
	glitch_amount += glitch_change

	if glitch_amount < glitch_min:
		glitch_amount = (glitch_max + glitch_amount) if cycle else glitch_min
	
	if glitch_amount > glitch_max:
		glitch_amount = (fmod(glitch_amount, glitch_max)) if cycle else glitch_max

	return glitch_amount

func _get_glitched_image(glitch_amount: float, color_offset: int, scan_lines: bool) -> Result:
	"""
	Glitches the image located at the given path
	Intensity of glitch depends on the glitch_amount
	"""
	var max_offset := int(pow(glitch_amount, 2 / 100) * img_size.x)
	var doubled_glitch_amount := int(glitch_amount * 2)
	for shift_number in range(0, doubled_glitch_amount):
		if has_seed:
			_reset_rng_seed(shift_number)
		
		var current_offset: int = rng.randi_range(-max_offset, max_offset)

		if current_offset == 0:
			continue
		elif current_offset < 0:
			_glitch_left(-current_offset)
		else:
			_glitch_right(current_offset)

	if has_seed:
		_reset_rng_seed()

	# Intentionally checking to see if this is 0, not if it's null
	if color_offset:
		var random_channel: int = _get_random_channel()
		_color_offset(rng.randi_range(-doubled_glitch_amount, doubled_glitch_amount),
				rng.randi_range(-doubled_glitch_amount, doubled_glitch_amount),
				random_channel)

	if scan_lines:
		_add_scan_lines()

	var image := Image.new()
	if image.create_from_data(img_size.x, img_size.y, false, Image.FORMAT_RGBA8, output_arr) != OK:
		return Result.new(
			null,
			Error.new(
				Error.Code.GLITCH_THIS_UNABLE_TO_CREATE_FROM_DATA,
				"Error when creating glitched image"))

	return Result.new(image)

func _add_scan_lines() -> void:
	# TODO stub
	pass

func _glitch_left(offset: int) -> void:
	# TODO stub
	pass

func _glitch_right(offset: int) -> void:
	# TODO stub
	pass

func _color_offset(offset_x: int, offset_y: int, channel_index: int) -> void:
	# TODO stub
	pass

#endregion

###############################################################################
# Public functions                                                            #
###############################################################################

func glitch_image(
	src_img,
	glitch_amount: float,
	p_random_seed = null,
	glitch_change: float = 0.0,
	color_offset: bool = false,
	scan_lines: bool = false,
	gif: bool = false,
	cycle: bool = false,
	frames: int = 23,
	step: int = -1
) -> Result:
	"""
	Sets up values needed for glitching the image
	
	Params:
		src_img: Path to input Image or the actual Image object
		glitch_amount: Level of glitch intensity [0.1, 10.0] (inclusive)
		p_random_seed: Set a random seed for generating similar images across runs
		glitch_change: Increment/decrement in glitch_amount after every glitch
		cycle: Whether or not to cycle glitch_amount back to glitch_min or glitch_max
			   if it over/underflows
		color_offset: Specify if color_offset effect should be applied
		scan_lines: Specify if scan_lines effect should be applied
		gif: If output should be ready to be saved as GIF
		frames: How many glitched frames should be generated for GIF
		step: Glitch every step'th frame, defaults to 1 (i.e. all frames)
	
	Returns:
		Image object if gif=false
		Array of Image objects if gif=true
	"""
	if p_random_seed != null:
		random_seed = p_random_seed
		has_seed = true

	if has_seed:
		_reset_rng_seed()
	
	var img_result: Result = _fetch_image(src_img, false)
	if img_result.is_err():
		return img_result
	
	var img: Image = img_result.expect("Unable to get image from result")
	
	# Fetching image attributes
	pixel_tuple_len = 3 # TODO hardcoded since there's no Godot equivalent to Image.getbands()
	img_size = img.get_size()
	img_mode = img.get_format()
	
	# TODO we need to manually construct the 3D array
	# Assigning the 3D arrays with pixel data
	input_arr = img.get_data()
	
	output_arr = []
	output_arr.resize(input_arr.size())
	
	if not gif:
		pass
	
	return Result.new(null)

func glitch_gif() -> Result:
	return Result.new(null, Error.new(Error.Code.GLITCH_THIS_NOT_SUPPORTED, "glitch_gif not implemented"))
