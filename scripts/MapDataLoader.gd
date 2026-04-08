extends RefCounted


func load_map_countries(path: String) -> Dictionary:
	var countries := {}

	if not FileAccess.file_exists(path):
		push_error("MapDataLoader: Map dataset missing at %s." % path)
		return countries

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("MapDataLoader: Failed to open %s." % path)
		return countries

	var content := file.get_as_text()
	var json := JSON.new()
	if json.parse(content) != OK:
		push_error("MapDataLoader: JSON parse error for %s." % path)
		return countries

	var payload: Dictionary = json.get_data()
	var raw_countries: Dictionary = payload.get("countries", {})

	for id in raw_countries.keys():
		var raw_country: Dictionary = raw_countries[id]
		var polygons: Array = []
		for raw_polygon in raw_country.get("polygons", []):
			var polygon := PackedVector2Array()
			for raw_point in raw_polygon:
				polygon.append(Vector2(float(raw_point[0]), float(raw_point[1])))
			if not polygon.is_empty():
				polygons.append(polygon)

		var bbox_raw: Dictionary = raw_country.get("bbox", {})
		var bbox_position_raw: Array = bbox_raw.get("position", [0.0, 0.0])
		var bbox_size_raw: Array = bbox_raw.get("size", [0.0, 0.0])
		var bbox_center_raw: Array = bbox_raw.get("center", [0.0, 0.0])

		var label_anchor_raw: Array = raw_country.get("label_anchor", [0.0, 0.0])
		var capital_coord_raw: Array = raw_country.get("capital_coord", [])

		countries[id] = {
			"id": raw_country.get("id", id),
			"display_name": raw_country.get("display_name", id),
			"polygons": polygons,
			"bbox": Rect2(
				Vector2(float(bbox_position_raw[0]), float(bbox_position_raw[1])),
				Vector2(float(bbox_size_raw[0]), float(bbox_size_raw[1]))
			),
			"bbox_center": Vector2(float(bbox_center_raw[0]), float(bbox_center_raw[1])),
			"label_anchor": Vector2(float(label_anchor_raw[0]), float(label_anchor_raw[1])),
			"capital_name": raw_country.get("capital_name", ""),
			"capital_coord": _to_vector2_or_zero(capital_coord_raw),
			"importance": float(raw_country.get("importance", 0.5)),
			"has_simulation_data": bool(raw_country.get("has_simulation_data", false)),
			"is_disputed": bool(raw_country.get("is_disputed", false)),
		}

	return countries


func _to_vector2_or_zero(raw_value: Variant) -> Vector2:
	if raw_value is Array and raw_value.size() >= 2:
		return Vector2(float(raw_value[0]), float(raw_value[1]))
	return Vector2.ZERO
