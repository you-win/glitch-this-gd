extends Control

signal image_loaded(result)

const Result = preload("res://addons/glitch-this-gd/model/result.gd")
const Error = preload("res://addons/glitch-this-gd/model/error.gd")

const VALID_EXTENSIONS := [
	"png",
	"jpg",
	"bmp",
	"webp",
	"tga"
]

var logger: Reference = load("res://addons/glitch-this-gd/logger.gd").new()
var glitch_this: Reference = load("res://addons/glitch-this-gd/glitch_this.gd").new()

var plugin: Node

var dir := Directory.new()

onready var send_it: Button = $Container/VBoxContainer/SendIt

onready var select_line_edit: LineEdit = $Container/VBoxContainer/HBoxContainer/Left/FileSelect/FileSelect/LineEdit
onready var select_browse_button: Button = $Container/VBoxContainer/HBoxContainer/Left/FileSelect/FileSelect/Button
onready var select_send_button: Button = $Container/VBoxContainer/HBoxContainer/Left/FileSelect/Button

onready var save_line_edit: LineEdit = $Container/VBoxContainer/HBoxContainer/Left/FileSave/FileSave/LineEdit
onready var save_browse_button: Button = $Container/VBoxContainer/HBoxContainer/Left/FileSave/FileSave/Button
onready var save_send_button: Button = $Container/VBoxContainer/HBoxContainer/Left/FileSave/Button

onready var input_tex_rect: TextureRect = $Container/VBoxContainer/HBoxContainer/Middle/Input
onready var output_tex_rect: TextureRect = $Container/VBoxContainer/HBoxContainer/Right/Output

var current_file_path: String = ""

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	_setup()

###############################################################################
# Connections                                                                 #
###############################################################################

func _on_image_loaded(result: Result) -> void:
	if result.is_err():
		logger.error(result.error.error_name())
		return
	
	var image_texture := ImageTexture.new()
	image_texture.create_from_image(result.value)
	
	input_tex_rect.texture = image_texture
	
	send_it.disabled = false

func _on_send_it() -> void:
	var result: Result = glitch_this.glitch_image(input_tex_rect.texture.get_data(), 3.0)
	if result.is_err():
		logger.error(result.error.error_name())
		return
	
	var image_texture := ImageTexture.new()
	image_texture.create_from_image(result.value, 10.0)
	output_tex_rect.texture = image_texture

#region Load

func _on_select_text_changed(text: String) -> void:
	if text.is_abs_path():
		select_send_button.disabled = not dir.file_exists(text)
	else:
		select_send_button.disabled = true

func _on_select_browse_button_pressed() -> void:
	logger.trace("Not yet implemented")

func _on_select_send_button_pressed() -> void:
	logger.trace("Not yet implemented")

#endregion

#region Save

#endregion

###############################################################################
# Private functions                                                           #
###############################################################################

func _setup() -> void:
	logger.setup("main")
	send_it.connect("pressed", self, "_on_send_it")
	send_it.disabled = true
	connect("image_loaded", self, "_on_image_loaded")
	_setup_file_select()
	_setup_file_save()

func _setup_file_select() -> void:
	select_line_edit.connect("text_changed", self, "_on_select_text_changed")
	select_browse_button.connect("pressed", self, "_on_select_browse_button_pressed")
	select_send_button.connect("pressed", self, "_on_select_send_button_pressed")

func _setup_file_save() -> void:
	save_line_edit.connect("text_changed", self, "_on_save_text_changed")
	save_browse_button.connect("pressed", self, "_on_save_browse_button_pressed")
	save_send_button.connect("pressed", self, "_on_save_send_button_pressed")

###############################################################################
# Public functions                                                            #
###############################################################################

func open_image(path: String) -> void:
	"""
	Opens an image from a path
	Does not directly return a value so that this can play nice as a Godot plugin
	"""
	if not path.get_extension().to_lower() in VALID_EXTENSIONS:
		# emit_signal("image_loaded", Result.new(null, Error.new(Error.Code.UNRECOGNIZED_FILE_TYPE)))
		return
	
	var image := Image.new()
	
	if image.load(path) != OK:
		emit_signal("image_loaded", Result.new(null, Error.new(Error.Code.FILE_NOT_FOUND)))
		return
	
	current_file_path = path
	
	emit_signal("image_loaded", Result.new(image))
