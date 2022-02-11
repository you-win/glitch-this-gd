extends Control

var logger: Reference = load("res://addons/glitch-this-gd/logger.gd").new()
var glitch_this: Reference = load("res://addons/glitch-this-gd/glitch_this.gd").new()

var plugin: Node

onready var menu: Tree = $MarginContainer/HBoxContainer/Tree

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	pass

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

###############################################################################
# Public functions                                                            #
###############################################################################

func open_image(path: String) -> void:
	pass
