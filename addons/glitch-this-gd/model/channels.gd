extends Reference

var size := Vector2.ZERO

# Regular arrays are used because PoolArrays don't have `slice` methods
var r := []
var g := []
var b := []
var a := []

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _init(image: Image = null) -> void:
	if image != null:
		deconstruct_image(image)

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

func _create_color_array() -> PoolColorArray:
	var pca := PoolColorArray([])
	
	for i in size.x * size.y:
		pca.append(Color(r[i], g[i], b[i], a[i]))
	
	return pca

###############################################################################
# Public functions                                                            #
###############################################################################

func deconstruct_image(image: Image) -> void:
	# Internally, godot locks/unlocks the image automatically for some reason
	# So call this first, otherwise the image will be unexpectedly unlocked
	size = image.get_size()

	image.lock()

	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)

			r.append(color.r)
			g.append(color.g)
			b.append(color.b)
			a.append(color.a)

	image.unlock()

func reconstruct_image() -> Image:
	var colors := _create_color_array()

	var image := Image.new()

	image.create(size.x, size.y, false, Image.FORMAT_RGBA8)

	image.lock()

	var i: int = 0
	for y in size.y:
		for x in size.x:
			image.set_pixel(x, y, colors[i])
			
			i += 1

	image.unlock()
	
	return image
