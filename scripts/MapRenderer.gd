extends Node2D

const GeoJSONParser = preload("res://scripts/GeoJSONParser.gd")
const BorderShader = preload("res://shaders/tactical_border.gdshader")
const CountryLabelScript = preload("res://scripts/CountryLabel.gd")

var parser = GeoJSONParser.new()

# Pro Strategic Palette
const COLOR_OCEAN_FALLBACK = Color(0.01, 0.02, 0.05, 1.0)
const COLOR_PLAYER = Color(0.0, 0.5, 1.0, 0.3)
const COLOR_OTHERS = Color(0.0, 0.0, 0.0, 0.0)
const COLOR_BORDER = Color(0.0, 0.6, 1.0, 1.0)
const COLOR_CITY = Color(1, 1, 1, 1)

const CAPITALS = {
	"BRA": {"name": "Brasília", "lon": -47.88, "lat": -15.79},
	"USA": {"name": "Washington D.C.", "lon": -77.03, "lat": 38.90},
	"CHN": {"name": "Beijing", "lon": 116.40, "lat": 39.90},
	"RUS": {"name": "Moscow", "lon": 37.61, "lat": 55.75},
	"GBR": {"name": "London", "lon": -0.12, "lat": 51.50},
	"FRA": {"name": "Paris", "lon": 2.35, "lat": 48.85},
	"DEU": {"name": "Berlin", "lon": 13.40, "lat": 52.52},
	"JPN": {"name": "Tokyo", "lon": 139.69, "lat": 35.68}
}

func _ready():
	_setup_background()
	generate_world_map()

func _setup_background():
	var fallback = ColorRect.new()
	fallback.name = "ColorFallback"
	fallback.color = COLOR_OCEAN_FALLBACK
	fallback.offset_left = -10000
	fallback.offset_top = -6000
	fallback.offset_right = 10000
	fallback.offset_bottom = 6000
	add_child(fallback)
	
	var sprite = Sprite2D.new()
	sprite.name = "SatelliteBackground"
	var texture = load("res://assets/maps/satellite_world.jpg")
	if texture:
		sprite.texture = texture
		var target_scale = (360.0 * 10.0) / texture.get_width()
		sprite.scale = Vector2(target_scale, target_scale)
	add_child(sprite)

func generate_world_map():
	var world_data = parser.load_world_map("res://data/world_map.geojson")
	if world_data.is_empty(): return
	
	for id in world_data:
		_render_country(id, world_data[id])
	
	_render_capitals()

func _render_country(id: String, country_info: Dictionary):
	var country_node = Node2D.new()
	country_node.name = id
	add_child(country_node)
	
	var is_player = (id == WorldManager.player_country_id)
	var base_fill = COLOR_PLAYER if is_player else COLOR_OTHERS
	var b_color = COLOR_BORDER if is_player else COLOR_BORDER.darkened(0.5)
	
	var mat = ShaderMaterial.new()
	mat.shader = BorderShader
	mat.set_shader_parameter("border_color", b_color)
	mat.set_shader_parameter("glow_intensity", 2.0 if is_player else 1.1)
	
	for points in country_info.polygons:
		var poly = Polygon2D.new()
		poly.polygon = points
		poly.color = base_fill
		
		var border = Line2D.new()
		border.points = points
		border.width = 1.2
		border.default_color = b_color
		border.material = mat
		border.antialiased = true
		
		var area = Area2D.new()
		var collision = CollisionPolygon2D.new()
		collision.polygon = points
		area.add_child(collision)
		
		country_node.add_child(poly)
		country_node.add_child(border)
		poly.add_child(area)
		
		area.input_event.connect(_on_country_input.bind(id))
		area.mouse_entered.connect(_on_country_hover.bind(country_node, true))
		area.mouse_exited.connect(_on_country_hover.bind(country_node, false))

	_add_country_label(id, country_info)

func _add_country_label(id: String, country_info: Dictionary):
	var label = Label.new()
	label.text = country_info.name.to_upper()
	label.set_script(CountryLabelScript)
	label.name = "Label_" + id
	label.position = country_info.centroid
	label.z_index = 20
	add_child(label)

func _render_capitals():
	var layer = Node2D.new()
	layer.name = "Capitals"
	add_child(layer)
	
	for id in CAPITALS:
		var city = CAPITALS[id]
		var marker = Polygon2D.new()
		var points = PackedVector2Array([
			Vector2(-3, -1), Vector2(-1, -3), Vector2(1, -3), 
			Vector2(3, -1), Vector2(3, 1), Vector2(1, 3), 
			Vector2(-1, 3), Vector2(-3, 1)
		])
		marker.polygon = points
		marker.color = COLOR_CITY
		marker.position = Vector2(city.lon * 10.0, -city.lat * 10.0)
		marker.scale = Vector2(0.3, 0.3)
		marker.z_index = 15
		layer.add_child(marker)

func _on_country_input(_viewport, event, _shape_idx, id):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		WorldManager.select_country(id)

func _on_country_hover(node, entering):
	var is_player = (node.name == WorldManager.player_country_id)
	for child in node.get_children():
		if child is Polygon2D:
			child.color.a = 0.6 if entering else (0.4 if is_player else 0.0)
		if child is Line2D:
			child.width = 2.5 if entering else 1.2
