extends Node

enum Mode { POLITICAL, POPULATION, GDP, GDP_PER_CAPITA, ALIGNMENT }
enum AlignmentReference { PLAYER, SELECTED }

const MODE_SEQUENCE := [
	Mode.POLITICAL,
	Mode.POPULATION,
	Mode.GDP,
	Mode.GDP_PER_CAPITA,
	Mode.ALIGNMENT,
]

var current_mode: int = Mode.POLITICAL
var current_alignment_reference: int = AlignmentReference.PLAYER


static func mode_label(mode: int) -> String:
	match mode:
		Mode.POLITICAL:
			return "Political"
		Mode.POPULATION:
			return "Population"
		Mode.GDP:
			return "GDP"
		Mode.GDP_PER_CAPITA:
			return "GDP per Capita"
		Mode.ALIGNMENT:
			return "Alignment"
		_:
			return "Political"


static func mode_button_label(mode: int) -> String:
	match mode:
		Mode.POLITICAL:
			return "Political"
		Mode.POPULATION:
			return "Population"
		Mode.GDP:
			return "GDP"
		Mode.GDP_PER_CAPITA:
			return "GDP/Capita"
		Mode.ALIGNMENT:
			return "Alignment"
		_:
			return "Political"


static func alignment_reference_label(reference_mode: int) -> String:
	match reference_mode:
		AlignmentReference.PLAYER:
			return "Jogador"
		AlignmentReference.SELECTED:
			return "Selecionado"
		_:
			return "Jogador"


static func legend_items_for_mode(mode: int) -> Array:
	match mode:
		Mode.POLITICAL:
			return [
				"Base politica neutra",
				"Hover usa cor de relacao",
				"Jogador e selecao continuam destacados",
			]
		Mode.POPULATION:
			return [
				"<10M",
				"10-30M",
				"30-80M",
				"80-200M",
				">200M",
			]
		Mode.GDP:
			return [
				"<50B",
				"50-250B",
				"250B-1T",
				"1-5T",
				">5T",
			]
		Mode.GDP_PER_CAPITA:
			return [
				"<5k",
				"5k-15k",
				"15k-30k",
				"30k-50k",
				">50k",
			]
		Mode.ALIGNMENT:
			return [
				"Self",
				"Allied",
				"Friendly",
				"Neutral",
				"Competitive",
				"Adversarial",
			]
		_:
			return []


func set_mode(new_mode: int):
	current_mode = new_mode
	_apply_to_map_layer()


func set_alignment_reference(new_reference: int):
	current_alignment_reference = new_reference
	_apply_to_map_layer()


func _apply_to_map_layer():
	var map_layer = get_tree().root.find_child("MapLayer", true, false)
	if map_layer == null:
		return

	if map_layer.has_method("set_visual_mode"):
		map_layer.set_visual_mode(current_mode)
	if map_layer.has_method("set_alignment_reference"):
		map_layer.set_alignment_reference(current_alignment_reference)
