extends Node

# Scales longitude/latitude to Godot 2D coordinates
# Longitude: -180 to 180
# Latitude: -90 to 90
const SCALE = 10.0

func load_world_map(path: String) -> Dictionary:
	var world_data = {}
	
	if not FileAccess.file_exists(path):
		push_error("GeoJSONParser: File not found at " + path)
		return world_data
		
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)
	
	if error != OK:
		push_error("GeoJSONParser: JSON parse error at line " + str(json.get_error_line()))
		return world_data
		
	var data = json.get_data()
	if not data.has("features"):
		push_error("GeoJSONParser: Invalid GeoJSON format (no features found).")
		return world_data
		
	for feature in data["features"]:
		var props = feature.get("properties", {})
		var id = props.get("iso_a3", "UNK")
		if id == "-99": # Some datasets use -99 for disputed territories
			id = props.get("adm0_a3", "UNK")
			
		var name = props.get("name", "Unknown")
		var geometry = feature.get("geometry", {})
		var type = geometry.get("type", "")
		var coords = geometry.get("coordinates", [])
		
		var polygons = []
		
		if type == "Polygon":
			polygons.append(_parse_polygon_coords(coords))
		elif type == "MultiPolygon":
			for poly_coords in coords:
				polygons.append(_parse_polygon_coords(poly_coords))
				
		world_data[id] = {
			"name": name,
			"polygons": polygons,
			"color": Color(randf_range(0.1, 0.4), randf_range(0.1, 0.4), randf_range(0.1, 0.4)) # Random base color
		}
		
	return world_data

func _parse_polygon_coords(poly_coords: Array) -> PackedVector2Array:
	var points = PackedVector2Array()
	# GeoJSON polygons are arrays of rings; first ring is the exterior
	# We only care about the exterior ring for simplification for now
	var exterior_ring = poly_coords[0]
	for coord in exterior_ring:
		var lon = float(coord[0])
		var lat = float(coord[1])
		# Flip Y because Godot 2D Y is down
		points.append(Vector2(lon * SCALE, -lat * SCALE))
	return points
