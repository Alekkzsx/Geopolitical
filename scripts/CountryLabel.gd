extends Label

# Minimalist technical font or standard Godot font
# We will auto-hide and scale this label based on the map's zoom level

@export var min_visible_zoom: float = 0.5
@export var base_font_size: int = 14

func _ready():
	# Configure professional appearance
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Shadow/Outline for readability on satellite terrain
	add_theme_constant_override("outline_size", 4)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_theme_font_size_override("font_size", base_font_size)
	
	# Initial visibility
	modulate.a = 0

func _process(_delta):
	# Access the parent MapManager2D to get the current zoom
	var map_layer = get_parent().get_parent() # MapRenderer -> MapLayer
	if not map_layer: return
	
	var current_zoom = map_layer.scale.x
	
	# Fade-in/out based on zoom
	if current_zoom < min_visible_zoom:
		modulate.a = lerp(modulate.a, 0.0, 0.1)
	else:
		# More zoom = more opacity
		var target_a = clamp((current_zoom - min_visible_zoom) * 2.0, 0.0, 1.0)
		modulate.a = lerp(modulate.a, target_a, 0.1)
	
	# Counter-scale to keep labels readable regardless of zoom
	# scale = Vector2(1.0 / current_zoom, 1.0 / current_zoom)
