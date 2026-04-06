extends Node

# Simplified polygons for the Strategic Map (Equirectangular scale)
# Longitude -> X, Latitude -> Y
# 180W to 180E -> -180 to 180
# 90N to 90S -> 90 to -90 (Godot uses Y down, so we flip)

const COUNTRIES = {
	"BRA": {
		"name": "Brasil",
		"polygon": [
			Vector2(-70, 0), Vector2(-55, -2), Vector2(-50, -10), Vector2(-45, -20),
			Vector2(-50, -32), Vector2(-58, -30), Vector2(-65, -20), Vector2(-73, -10),
			Vector2(-70, 0)
		],
		"color": Color(0, 0.4, 0.1) # Default (Green-ish)
	},
	"USA": {
		"name": "USA",
		"polygon": [
			Vector2(-125, 48), Vector2(-122, 32), Vector2(-117, 32), Vector2(-114, 25),
			Vector2(-97, 26), Vector2(-80, 25), Vector2(-70, 42), Vector2(-67, 47),
			Vector2(-125, 48)
		],
		"color": Color(0, 0, 0.6)
	},
	"CHN": {
		"name": "China",
		"polygon": [
			Vector2(75, 40), Vector2(85, 50), Vector2(120, 50), Vector2(125, 35),
			Vector2(110, 20), Vector2(100, 20), Vector2(75, 40)
		],
		"color": Color(0.6, 0.1, 0)
	},
	"RUS": {
		"name": "Russia",
		"polygon": [
			Vector2(30, 70), Vector2(50, 75), Vector2(120, 75), Vector2(170, 70),
			Vector2(170, 50), Vector2(100, 50), Vector2(30, 70)
		],
		"color": Color(0.6, 0, 0)
	}
}

static func get_packed_points(id):
	var points = PackedVector2Array()
	var raw = COUNTRIES[id].polygon
	for p in raw:
		# Scale factors for a reasonable pixel map
		points.append(Vector2(p.x * 10, -p.y * 10))
	return points
