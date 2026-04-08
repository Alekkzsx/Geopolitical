extends Node

const MapDataLoader = preload("res://scripts/MapDataLoader.gd")
const MapModes = preload("res://scripts/MapModesManager.gd")

signal country_selected(country_payload)
signal tick(date_str)

var countries: Dictionary = {}
var map_countries: Dictionary = {}
var map_sites: Array = []
var alignment_overrides: Dictionary = {}
var selected_country_id: String = ""
var player_country_id: String = "BRA"
var game_date := {"day": 1, "month": 1, "year": 2024}
var timer: float = 0.0
var time_speed: float = 1.0

var _map_loader = MapDataLoader.new()
var _sites_by_country: Dictionary = {}


func _ready():
	load_data()


func load_data():
	countries = _load_json_dictionary("res://data/countries.json", "WorldManager: Simulation database missing.")
	map_countries = _map_loader.load_map_countries("res://data/map_countries.json")
	map_sites = _map_loader.load_map_sites("res://data/map_sites.json")
	alignment_overrides = _load_json_dictionary("res://data/alignment_overrides_v1.json", "WorldManager: Alignment overrides missing.")
	_rebuild_sites_index()


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

	var date_str: String = "%02d/%02d/%d" % [game_date.day, game_date.month, game_date.year]
	emit_signal("tick", date_str)


func select_country(id: String):
	var map_data: Dictionary = map_countries.get(id, {})
	var simulation_data: Dictionary = countries.get(id, {})
	if map_data.is_empty() and simulation_data.is_empty():
		return

	selected_country_id = id
	emit_signal("country_selected", get_country_payload(id))


func get_country_payload(id: String) -> Dictionary:
	var map_data: Dictionary = map_countries.get(id, {})
	var simulation_data: Dictionary = countries.get(id, {})
	if map_data.is_empty() and simulation_data.is_empty():
		return {}

	var payload_map: Dictionary = map_data.duplicate(true)
	payload_map["alignment_to_player"] = get_alignment_state_between(id, player_country_id)

	var selected_alignment: Dictionary = {}
	if selected_country_id != "" and selected_country_id != id:
		selected_alignment = get_alignment_state_between(id, selected_country_id)
	payload_map["alignment_to_selected"] = selected_alignment
	payload_map["sites"] = get_sites_for_country(id)

	return {
		"id": id,
		"display_name": payload_map.get("display_name", simulation_data.get("name", id)),
		"capital_name": payload_map.get("capital_name", ""),
		"has_simulation_data": not simulation_data.is_empty(),
		"simulation": simulation_data.duplicate(true),
		"map": payload_map,
	}


func get_map_country(id: String) -> Dictionary:
	return map_countries.get(id, {})


func get_map_sites() -> Array:
	return map_sites


func get_sites_for_country(id: String) -> Array:
	return _sites_by_country.get(id, [])


func get_alignment_reference_country_id(reference_mode: int) -> String:
	if reference_mode == MapModes.AlignmentReference.SELECTED:
		if selected_country_id != "" and selected_country_id != player_country_id:
			return selected_country_id
	return player_country_id


func get_alignment_state(target_id: String, reference_mode: int) -> Dictionary:
	return get_alignment_state_between(target_id, get_alignment_reference_country_id(reference_mode))


func get_alignment_state_between(target_id: String, reference_id: String) -> Dictionary:
	if target_id == "" or reference_id == "":
		return _alignment_state_payload("neutral", 0, target_id, reference_id)
	if target_id == reference_id:
		return _alignment_state_payload("self", 2, target_id, reference_id)

	var target_country: Dictionary = get_map_country(target_id)
	var reference_country: Dictionary = get_map_country(reference_id)
	if target_country.is_empty() or reference_country.is_empty():
		return _alignment_state_payload("neutral", 0, target_id, reference_id)

	var score: int = 0
	if _shares_bloc(target_id, reference_id):
		score += 2

	var target_subregion: String = str(target_country.get("subregion", ""))
	var reference_subregion: String = str(reference_country.get("subregion", ""))
	if target_subregion != "" and target_subregion == reference_subregion:
		score += 1

	if _is_partner(target_id, reference_id):
		score += 2

	if _is_rival(target_id, reference_id):
		score -= 2

	score = clampi(score, -2, 2)
	return _alignment_state_payload(_alignment_key_for_score(score), score, target_id, reference_id)


func _alignment_state_payload(key: String, score: int, target_id: String, reference_id: String) -> Dictionary:
	var target_name: String = get_map_country(target_id).get("display_name", target_id)
	var reference_name: String = get_map_country(reference_id).get("display_name", reference_id)
	return {
		"key": key,
		"label": _alignment_label(key),
		"score": score,
		"target_id": target_id,
		"target_name": target_name,
		"reference_id": reference_id,
		"reference_name": reference_name,
	}


func _alignment_key_for_score(score: int) -> String:
	match score:
		2:
			return "allied"
		1:
			return "friendly"
		-1:
			return "competitive"
		-2:
			return "adversarial"
		_:
			return "neutral"


func _alignment_label(key: String) -> String:
	match key:
		"self":
			return "Self"
		"allied":
			return "Allied"
		"friendly":
			return "Friendly"
		"competitive":
			return "Competitive"
		"adversarial":
			return "Adversarial"
		_:
			return "Neutral"


func _shares_bloc(target_id: String, reference_id: String) -> bool:
	var target_blocs: Array = _string_array(_get_alignment_profile(target_id).get("blocs", []))
	var reference_blocs: Array = _string_array(_get_alignment_profile(reference_id).get("blocs", []))
	for bloc in target_blocs:
		if reference_blocs.has(bloc):
			return true
	return false


func _is_partner(target_id: String, reference_id: String) -> bool:
	var target_partners: Array = _string_array(_get_alignment_profile(target_id).get("partners", []))
	var reference_partners: Array = _string_array(_get_alignment_profile(reference_id).get("partners", []))
	return target_partners.has(reference_id) or reference_partners.has(target_id)


func _is_rival(target_id: String, reference_id: String) -> bool:
	var target_rivals: Array = _string_array(_get_alignment_profile(target_id).get("rivals", []))
	var reference_rivals: Array = _string_array(_get_alignment_profile(reference_id).get("rivals", []))
	return target_rivals.has(reference_id) or reference_rivals.has(target_id)


func _get_alignment_profile(country_id: String) -> Dictionary:
	return alignment_overrides.get(country_id, {})


func _string_array(values: Variant) -> Array:
	if not (values is Array):
		return []

	var result: Array = []
	for value in values:
		result.append(str(value))
	return result


func _rebuild_sites_index():
	_sites_by_country.clear()
	for site in map_sites:
		if not (site is Dictionary):
			continue

		var country_id: String = str(site.get("country_id", ""))
		if country_id == "":
			continue

		if not _sites_by_country.has(country_id):
			_sites_by_country[country_id] = []
		_sites_by_country[country_id].append(site)


func _load_json_dictionary(path: String, missing_message: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error(missing_message)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("WorldManager: Failed to open %s." % path)
		return {}

	var content: String = file.get_as_text()
	var json := JSON.new()
	if json.parse(content) != OK:
		push_error("WorldManager: JSON parse error for %s." % path)
		return {}

	var data: Variant = json.get_data()
	if data is Dictionary:
		return data

	push_error("WorldManager: Invalid JSON payload for %s." % path)
	return {}
