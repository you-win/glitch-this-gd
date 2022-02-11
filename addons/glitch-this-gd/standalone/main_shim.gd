extends CanvasLayer

const MAIN: PackedScene = preload("res://addons/glitch-this-gd/main.tscn")
const DUMMY_PLUGIN: GDScript = preload("res://addons/glitch-this-gd/standalone/dummy_plugin.gd")

var main: Control

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	main = MAIN.instance()
	main.plugin = DUMMY_PLUGIN.new()
	add_child(main)

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

###############################################################################
# Public functions                                                            #
###############################################################################