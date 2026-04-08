extends Node

const MapDataLoader = preload("res://scripts/MapDataLoader.gd")

signal country_selected(country_payload)
signal tick(date_str)

var countries: Dictionary = {}
var map_countries: Dictionary = {}
var selected_country_id: String = ""
var player_country_id: String = "BRA"
var game_date := {"day": 1, "month": 1, "year": 2024}
var timer: float = 0.0
var time_speed: float = 1.0

var _map_loader := MapDataLoader.new()


func _ready():
	load_data()


func load_data():
	countries = _load_json_dictionary("res://data/countries.json", "WorldManager: Simulation database missing.")
	map_countries = _map_loader.load_map_countries("res://data/map_countries.json")


func _process(delta: float):
	if time_speed <= 0.0:
		return

	timer += delta * time_speed
	if timer >= 1.0:
		timer = 0.0
		advance_time()


func advance_time():
	game_date.day += 1
	if game_date.day > 30:
		game_date.day = 1
		game_date.month += 1
		if game_date.month > 12:
			game_date.month = 1
			game_date.year += 1

	var date_str := "%02d/%02d/%d" % [game_date.day, game_date.month, game_date.year]
	emit_signal("tick", date_str)


func select_country(id: String):
	var map_data: Dictionary = map_countries.get(id, {})
	var simulation_data: Dictionary = countries.get(id, {})
	if map_data.is_empty() and simulation_data.is_empty():
		return

	selected_country_id = id

	var payload := {
		"id": id,
		"display_name": map_data.get("display_name", simulation_data.get("name", id)),
		"capital_name": map_data.get("capital_name", ""),
		"has_simulation_data": not simulation_data.is_empty(),
		"simulation": simulation_data,
		"map": map_data,
	}
	emit_signal("country_selected", payload)


func get_map_country(id: String) -> Dictionary:
	return map_countries.get(id, {})


func _load_json_dictionary(path: String, missing_message: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error(missing_message)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("WorldManager: Failed to open %s." % path)
		return {}

	var content := file.get_as_text()
	var json := JSON.new()
	if json.parse(content) != OK:
		push_error("WorldManager: JSON parse error for %s." % path)
		return {}

	var data: Variant = json.get_data()
	if data is Dictionary:
		return data

	push_error("WorldManager: Invalid JSON payload for %s." % path)
	return {}
