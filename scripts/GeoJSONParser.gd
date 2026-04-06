extends Node

const SCALE = 10.0

func load_world_map(path: String) -> Dictionary:
	var world_data = {}
	
	if not FileAccess.file_exists(path):
		return world_data
		
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)
	
	if error != OK:
		return world_data
		
	var data = json.get_data()
	for feature in data["features"]:
		var props = feature.get("properties", {})
		var id = props.get("iso_a3", "UNK")
		if id == "-99": id = props.get("adm0_a3", "UNK")
			
		var name = props.get("name", "Unknown")
		var geometry = feature.get("geometry", {})
		var type = geometry.get("type", "")
		var coords = geometry.get("coordinates", [])
		
		var polygons = []
		var all_points = PackedVector2Array() # To calculate centroid
		
		if type == "Polygon":
			var p = _parse_polygon_coords(coords)
			polygons.append(p)
			all_points.append_array(p)
		elif type == "MultiPolygon":
			for poly_coords in coords:
				var p = _parse_polygon_coords(poly_coords)
				polygons.append(p)
				all_points.append_array(p)
				
		world_data[id] = {
			"name": name,
			"polygons": polygons,
			"centroid": _calculate_centroid(all_points),
			"color": Color(randf_range(0.1, 0.4), randf_range(0.1, 0.4), randf_range(0.1, 0.4))
		}
		
	return world_data

func _parse_polygon_coords(poly_coords: Array) -> PackedVector2Array:
	var points = PackedVector2Array()
	var exterior_ring = poly_coords[0]
	for coord in exterior_ring:
		var lon = float(coord[0])
		var lat = float(coord[1])
		points.append(Vector2(lon * SCALE, -lat * SCALE))
	return points

func _calculate_centroid(points: PackedVector2Array) -> Vector2:
	if points.is_empty(): return Vector2.ZERO
	var sum = Vector2.ZERO
	for p in points:
		sum += p
	return sum / float(points.size())
