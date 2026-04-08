extends RefCounted


func load_map_countries(path: String) -> Dictionary:
	var payload: Variant = _load_json(path)
	if not (payload is Dictionary):
		push_error("MapDataLoader: Invalid country dataset payload for %s." % path)
		return {}

	var countries_payload: Variant = payload.get("countries", {})
	if not (countries_payload is Dictionary):
		push_error("MapDataLoader: Missing countries dictionary in %s." % path)
		return {}

	var countries: Dictionary = {}
	for id in countries_payload.keys():
		var source: Variant = countries_payload[id]
		if not (source is Dictionary):
			continue

		var source_country: Dictionary = source
		var polygons: Array = []
		for raw_polygon in source_country.get("polygons", []):
			if not (raw_polygon is Array):
				continue

			var polygon_points := PackedVector2Array()
			for raw_point in raw_polygon:
				polygon_points.append(_to_vector2(raw_point))

			if not polygon_points.is_empty():
				polygons.append(polygon_points)

		var bbox_payload: Dictionary = source_country.get("bbox", {})
		var bbox_position: Vector2 = _to_vector2(bbox_payload.get("position", [0.0, 0.0]))
		var bbox_size: Vector2 = _to_vector2(bbox_payload.get("size", [0.0, 0.0]))
		var bbox_center: Vector2 = _to_vector2(
			bbox_payload.get("center", [bbox_position.x + (bbox_size.x * 0.5), bbox_position.y + (bbox_size.y * 0.5)])
		)

		countries[id] = {
			"id": str(source_country.get("id", id)),
			"display_name": str(source_country.get("display_name", id)),
			"iso_a2": str(source_country.get("iso_a2", "")),
			"polygons": polygons,
			"bbox": Rect2(bbox_position, bbox_size),
			"bbox_center": bbox_center,
			"label_anchor": _to_vector2(source_country.get("label_anchor", [bbox_center.x, bbox_center.y])),
			"capital_name": str(source_country.get("capital_name", "")),
			"capital_coord": _to_vector2(source_country.get("capital_coord", [])),
			"importance": float(source_country.get("importance", 0.5)),
			"has_simulation_data": bool(source_country.get("has_simulation_data", false)),
			"is_disputed": bool(source_country.get("is_disputed", false)),
			"population_est": float(source_country.get("population_est", 0.0)),
			"gdp_est": float(source_country.get("gdp_est", 0.0)),
			"gdp_per_capita_est": float(source_country.get("gdp_per_capita_est", 0.0)),
			"region_un": str(source_country.get("region_un", "")),
			"subregion": str(source_country.get("subregion", "")),
			"economy_group": str(source_country.get("economy_group", "")),
			"income_group": str(source_country.get("income_group", "")),
		}

	return countries


func load_map_sites(path: String) -> Array:
	var payload: Variant = _load_json(path)
	if not (payload is Dictionary):
		push_error("MapDataLoader: Invalid site dataset payload for %s." % path)
		return []

	var sites_payload: Variant = payload.get("sites", [])
	if not (sites_payload is Array):
		push_error("MapDataLoader: Missing sites array in %s." % path)
		return []

	var sites: Array = []
	for raw_site in sites_payload:
		if not (raw_site is Dictionary):
			continue

		var site: Dictionary = raw_site
		sites.append({
			"id": str(site.get("id", "")),
			"country_id": str(site.get("country_id", "")),
			"name": str(site.get("name", "")),
			"type": str(site.get("type", "city")),
			"coord": _to_vector2(site.get("coord", [])),
			"population_est": float(site.get("population_est", 0.0)),
			"importance": float(site.get("importance", 0.5)),
		})

	return sites


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("MapDataLoader: File does not exist at %s." % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("MapDataLoader: Failed to open %s." % path)
		return {}

	var json := JSON.new()
	var parse_error: int = json.parse(file.get_as_text())
	if parse_error != OK:
		push_error("MapDataLoader: JSON parse error for %s." % path)
		return {}

	return json.get_data()


func _to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
