extends Node

enum Mode { POLITICAL, ECONOMY, SOCIAL, MILITARY }

var current_mode: Mode = Mode.POLITICAL


func set_mode(new_mode: Mode):
	current_mode = new_mode

	var map_layer = get_tree().root.find_child("MapLayer", true, false)
	if map_layer and map_layer.has_method("set_visual_mode"):
		map_layer.set_visual_mode(int(current_mode))
