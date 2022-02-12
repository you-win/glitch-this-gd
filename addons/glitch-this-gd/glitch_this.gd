extends Reference

const Result = preload("res://addons/glitch-this-gd/model/result.gd")
const Error = preload("res://addons/glitch-this-gd/model/error.gd")
const Channels = preload("res://addons/glitch-this-gd/model/channels.gd")

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
#var input_arr: PoolByteArray
#var output_arr: PoolByteArray

var input_channels: Channels
var output_channels: Channels

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
	# TODO stub
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

	return Result.new(output_channels.reconstruct_image())

func _add_scan_lines() -> void:
	"""
	Make every other row have only black pixels
	Only the R, G, and B channels are assigned 0 values
	Alpha is left untouched (if preset)

	We basically manually slice here in the Godot implementation, since we need to change the values
	at the specified slice steps, not just pull the values
	"""
	for i in output_channels.r.size():
		if i % 2 == 0:
			output_channels.r[i] = 0.0

	for i in output_channels.g.size():
		output_channels.g[i] = 0.0

	for i in output_channels.b.size():
		if i >= 3:
			break

		output_channels.b[i] = 0.0

func _glitch_left(offset: int) -> void:
	"""
	Grabs a rectangle from the input and shifts it leftwards
	Any lost pixel data is wrapped back to the right
	Rectangle's Width and Height are determined from offset

	The original uses fancy Python slice manipulation. We convert by channel instead
	"""
	# Setting up values that will determine the rectangle height
	var start_y: int = rng.randi_range(0, img_size.y)
	var chunk_height: int = rng.randi_range(1, int(img_size.y / 4))
	chunk_height = min(chunk_height, img_size.y - start_y)
	var stop_y: int = start_y + chunk_height

	# For copy
	var start_x: int = offset
	# For paste
	var stop_x: int = img_size.x - start_x

	# var left_chunk_r := channels.r.slice(start_y, stop_y)
	var left_chunk_g := input_channels.g.slice(0, start_x)

	# var wrap_chunk_r := channels.r.slice(start_y, stop_y)
	var wrap_chunk_g := input_channels.g.slice(start_x, input_channels.g.size())


	# TODO I don't think we need to process the R channel
	# It looks like this is only needed in the Python implementation
	# so that they can instead set the G channel using slice notation

	var counter: int = 0
	# for i in range(start_y, stop_y):
	# 	channels.r[i] = left_chunk_r[counter]
	# 	counter += 1
	
	# counter = 0
	for i in range(0, stop_x):
		if counter >= left_chunk_g.size():
			break
		output_channels.g[i] = left_chunk_g[counter]
		counter += 1
	counter = 0

	# counter = 0
	# for i in range(start_y, stop_y):
	# 	channels.r[i] = wrap_chunk_r[counter]
	# 	counter += 1

	for i in range(stop_x, output_channels.g.size()):
		if counter >= wrap_chunk_g.size():
			break
		output_channels.g[i] = wrap_chunk_g[counter]
		counter += 1
	counter = 0

func _glitch_right(offset: int) -> void:
	"""
	Grabs a rectangle from the input and shifts it rightwards
	Any lost pixel data is wrapped back to the left
	Rectangle's Width and Height are determined from offset
	"""
	# Setting up values that will determine the rectangle height
	var start_y: int = rng.randi_range(0, img_size.y)
	var chunk_height: int = rng.randi_range(1, int(img_size.y / 4))
	chunk_height = min(chunk_height, img_size.y - start_y)
	var stop_y: int = start_y + chunk_height

	# For copy
	var stop_x: int = img_size.x - offset
	# For paste
	var start_x: int = offset

	# var right_chunk_r := channels.r.slice(start_y, stop_y)
	var right_chunk_g := input_channels.g.slice(0, stop_x)

	# var wrap_chunk_r := channels.r.slice(start_y, stop_y)
	var wrap_chunk_g := input_channels.g.slice(stop_x, input_channels.g.size())

	# TODO I don't think we need to process the R channel
	# It looks like this is only needed in the Python implementation
	# so that they can instead set the G channel using slice notation

	var counter: int = 0
	# for i in range(start_y, stop_y):
	# 	channels.r[i] = right_chunk_r[counter]
	# 	counter += 1
	
	# counter = 0
	for i in range(start_x, output_channels.g.size()):
		if counter >= right_chunk_g.size():
			break
		output_channels.g[i] = right_chunk_g[counter]
		counter += 1
	counter = 0

	# counter = 0
	# for i in range(start_y, stop_y):
	# 	channels.r[i] = wrap_chunk_r[counter]
	# 	counter += 1

	for i in range(0, start_x):
		if counter >= wrap_chunk_g.size():
			break
		output_channels.g[i] = wrap_chunk_g[counter]
		counter += 1
	counter = 0

func _color_offset(offset_x: int, offset_y: int, channel_index: int) -> void:
	"""
	Takes the given channel's color value from the image starting from (0, 0)
	and puts it in the same channel's slot in the output starting from (offset_y, offset_x)

	Once again, we need to manually manipulate the channels instead of using Python slicing
	"""
	# Make sure offset_x isn't negative in the actual algo
	offset_x = offset_x if offset_x >= 0 else img_size.x + offset_x
	offset_y = offset_y if offset_y >= 0 else img_size.y + offset_y
	
	# Assign values from 0th row of input to offset_y'th
	# row of output
	# If output's column run out before input's do, wrap the remaining values around
	
	# TODO it looks like the B channel is always just copied from the input
	# Maybe it can be taken out?
	
	# Initialize all our helper variables for emulating fancy Python slicing
	var counter: int = 0
	var r_slice := []
	var g_slice := []
	var b_slice := []
	
	output_channels.r[offset_y] = input_channels.r[0]
	
	g_slice = input_channels.g.slice(0, img_size.x - offset_x)
	for i in range(offset_x, output_channels.g.size()):
		if counter >= g_slice.size():
			break
		output_channels.g[i] = g_slice[counter]
		counter += 1
	counter = 0
	
	output_channels.b[channel_index] = input_channels.b[channel_index]
	
	# Process wrap
	
	output_channels.r[offset_y] = input_channels.r[0]
	
	g_slice = input_channels.g.slice(img_size.x - offset_x, input_channels.g.size())
	for i in range(0, offset_x):
		if counter >= g_slice.size():
			break
		output_channels.g[i] = g_slice[counter]
		counter += 1
	counter = 0
	
	output_channels.b[channel_index] = input_channels.b[channel_index]
	
	# Continue afterwards till end of output
	# Make sure the width and height match for both slices
	r_slice = input_channels.r.slice(1, img_size.y - offset_y)
	for i in range(offset_y + 1, output_channels.r.size()):
		if counter >= r_slice.size():
			break
		output_channels.r[i] = r_slice[counter]
		counter += 1
	counter = 0
	
	# The G channel is just a straight copy, so skip processing it
	
	output_channels.b[channel_index] = input_channels.b[channel_index]
	
	# Restart from 0th row of output and go until the offset_y'th row
	# This will assign the remaining values in input to output
	r_slice = input_channels.r.slice(img_size.y - offset_y, input_channels.r.size())
	for i in range(0, offset_y):
		if counter >= r_slice.size():
			break
		output_channels.r[i] = r_slice[counter]
		counter += 1
	counter = 0
	
	# The G channel is just a straight copy, so skip processing it
	
	output_channels.b[channel_index] = input_channels.b[channel_index]

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
	
	# Assigning the 3D arrays with pixel data
	# Technically we're using a different approach in Godot
	input_channels = Channels.new(img)
	output_channels = Channels.new(img)
	
	if not gif:
		return _get_glitched_image(glitch_amount, color_offset, scan_lines)
	
	return Result.new(null)

func glitch_gif() -> Result:
	return Result.new(null, Error.new(Error.Code.GLITCH_THIS_NOT_SUPPORTED, "glitch_gif not implemented"))
