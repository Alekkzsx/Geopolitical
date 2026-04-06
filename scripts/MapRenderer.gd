extends Node2D

const GeoJSONParser = preload("res://scripts/GeoJSONParser.gd")
const BorderShader = preload("res://shaders/tactical_border.gdshader")
var parser = GeoJSONParser.new()

# Professional Strategic Palette
const COLOR_OCEAN = Color(0.02, 0.04, 0.1, 1.0)
const COLOR_PLAYER = Color(0.0, 0.5, 1.0, 0.4) # Semi-transparent blue for player
const COLOR_OTHERS = Color(0.0, 0.0, 0.0, 0.0) # Invisible by default to show satellite
const COLOR_BORDER = Color(0.0, 0.6, 1.0, 1.0) # Glowing Cyan border

func _ready():
	_setup_background()
	generate_world_map()

func _setup_background():
	# Satellite World Background
	var sprite = Sprite2D.new()
	sprite.name = "SatelliteBackground"
	var texture = load("res://assets/maps/satellite_world.jpg")
	if texture:
		sprite.texture = texture
		# Match the 10.0 scale from GeoJSONParser
		# 3600 pixels width / 2048 texture width = 1.7578
		var target_scale = (360.0 * 10.0) / texture.get_width()
		sprite.scale = Vector2(target_scale, target_scale)
		# Center it (Godot Sprite2D centers by default, which is good for -180..180)
	add_child(sprite)

func generate_world_map():
	# Existing map logic, but adding Line2D for borders
	var world_data = parser.load_world_map("res://data/world_map.geojson")
	if world_data.is_empty():
		return
		
	print("MapRenderer: Tactical Rendering Started.")
	
	for id in world_data:
		var country = world_data[id]
		_render_country(id, country)

func _render_country(id: String, country_info: Dictionary):
	var country_node = Node2D.new()
	country_node.name = id
	add_child(country_node)
	
	var base_fill = COLOR_OTHERS
	var border_color = COLOR_BORDER.darkened(0.5)
	
	if id == "BRA":
		base_fill = COLOR_PLAYER
		border_color = COLOR_BORDER # Bright for player
	
	# Create ShaderMaterial for the border
	var mat = ShaderMaterial.new()
	mat.shader = BorderShader
	mat.set_shader_parameter("border_color", border_color)
	mat.set_shader_parameter("glow_intensity", 2.5 if id == "BRA" else 1.2)
	
	for points in country_info.polygons:
		# VISUAL: Polygon (Fill)
		var poly = Polygon2D.new()
		poly.polygon = points
		poly.color = base_fill
		
		# VISUAL: Line2D (Glowing Border)
		var border = Line2D.new()
		border.points = points
		border.width = 1.5
		border.default_color = border_color
		border.material = mat # Apply tactical glow shader
		border.joint_mode = Line2D.LINE_JOINT_ROUND
		border.begin_cap_mode = Line2D.LINE_CAP_ROUND
		border.end_cap_mode = Line2D.LINE_CAP_ROUND
		
		# Interaction Area
		var area = Area2D.new()
		var collision = CollisionPolygon2D.new()
		collision.polygon = points
		
		area.add_child(collision)
		poly.add_child(area)
		
		country_node.add_child(poly)
		country_node.add_child(border)
		
		# Signals
		area.input_event.connect(_on_country_input.bind(id))
		area.mouse_entered.connect(_on_country_hover.bind(country_node, true))
		area.mouse_exited.connect(_on_country_hover.bind(country_node, false))

func _on_country_input(_viewport, event, _shape_idx, id):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		WorldManager.select_country(id)

func _on_country_hover(node, entering):
	for child in node.get_children():
		if child is Polygon2D:
			if entering:
				child.color.a = 0.6
			else:
				child.color.a = 0.4 if node.name == "BRA" else 0.0
		if child is Line2D:
			# Visual pulse or highlight on border
			if entering:
				child.width = 3.0
			else:
				child.width = 1.5
