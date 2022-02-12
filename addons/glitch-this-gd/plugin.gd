tool
extends EditorPlugin

const PLUGIN_NAME := "Glitch This GD"

var logger: Reference = load("res://addons/glitch-this-gd/logger.gd").new()

var main: Control
var file_system: Tree

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _enter_tree():
	logger.setup(self)
	
	main = load("res://addons/glitch-this-gd/main.tscn").instance()
	inject_tool(main)
	main.plugin = self
	
	add_control_to_bottom_panel(main, PLUGIN_NAME)
	
	make_visible(false)
	
	file_system = _get_editor_filesystem()
	if not file_system:
		printerr("Unable to get editor file system\nThis is 100% a bug\nPlease disable the plugin")
	
	file_system.connect("multi_selected", self, "_on_file_system_multi_selected")

func _exit_tree():
	if main != null:
		remove_control_from_bottom_panel(main)
		main.queue_free()
	if file_system != null:
		file_system.disconnect("multi_selected", self, "_on_file_system_multi_selected")

func enable_plugin():
	make_bottom_panel_item_visible(main)

func make_visible(visible):
	if main != null:
		main.visible = visible
		main.set_process(visible)
		main.set_process_input(visible)
		main.set_process_internal(visible)
		main.set_process_unhandled_input(visible)
		main.set_process_unhandled_key_input(visible)

func get_plugin_name():
	return PLUGIN_NAME

func get_plugin_icon():
	return get_editor_interface().get_base_control().get_icon("CanvasLayer", "EditorIcons")

###############################################################################
# Connections                                                                 #
###############################################################################

func _on_file_system_multi_selected(item: TreeItem, column: int, selected: bool) -> void:
	if not selected:
		return
	
	main.open_image("%s/%s" % [
		ProjectSettings.globalize_path(get_editor_interface().get_selected_path()),
		item.get_text(column)])

###############################################################################
# Private functions                                                           #
###############################################################################

func _get_editor_filesystem() -> Tree:
	for c0 in get_editor_interface().get_file_system_dock().get_children():
		if c0 is VSplitContainer:
			for c1 in c0.get_children():
				if c1 is Tree:
					return c1
	return null

###############################################################################
# Public functions                                                            #
###############################################################################

func inject_tool(node: Node) -> void:
	"""
	Inject `tool` at the top of the plugin script
	"""
	var script: Script = node.get_script().duplicate()
	script.source_code = "tool\n%s" % script.source_code
	script.reload(false)
	node.set_script(script)
