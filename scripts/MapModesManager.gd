extends Node

# Global Map Modes
enum Mode { POLITICAL, ECONOMY, SOCIAL, MILITARY }

var current_mode = Mode.POLITICAL

# Heatmap Palette (Low to High intensity)
const PALETTE_ECONOMY = [
	Color(0.8, 0.2, 0.2, 0.4), # Red (Stagnation)
	Color(0.8, 0.8, 0.2, 0.4), # Yellow (Stable)
	Color(0.2, 0.8, 0.2, 0.4)  # Green (Growth)
]

func set_mode(new_mode: Mode):
	current_mode = new_mode
	_update_map_visuals()

func _update_map_visuals():
	var map_renderer = get_tree().root.find_child("Countries", true, false)
	if not map_renderer: return
	
	# Loop through all countries in the map
	var countries_data = WorldManager.countries
	
	for id in countries_data:
		var country_node = map_renderer.find_child(id, true, false)
		if not country_node: continue
		
		var color = _get_color_for_mode(id, countries_data[id])
		
		# Update all Polygon2D children of this country
		for child in country_node.get_children():
			if child is Polygon2D:
				child.color = color

func _get_color_for_mode(id: String, stats: Dictionary) -> Color:
	if id == WorldManager.player_country_id and current_mode == Mode.POLITICAL:
		return Color(0.0, 0.5, 1.0, 0.3) # Default Player Highlight
		
	match current_mode:
		Mode.POLITICAL:
			return Color(0, 0, 0, 0) # Transparent / Satellite View
		Mode.ECONOMY:
			# Growth based heatmap (Target 0 to 5%)
			var growth = stats.get("growth", 0.0)
			var weight = clamp(growth / 5.0, 0.0, 1.0)
			return _interpolate_palette(PALETTE_ECONOMY, weight)
		Mode.SOCIAL:
			# Stability based
			var stab = stats.get("stability", 50.0)
			var weight = clamp(stab / 100.0, 0.0, 1.0)
			return Color(1.0, 0.5, 0.0, weight * 0.4)
		_:
			return Color(0, 0, 0, 0)

func _interpolate_palette(palette: Array, weight: float) -> Color:
	if weight <= 0.5:
		return palette[0].lerp(palette[1], weight * 2.0)
	else:
		return palette[1].lerp(palette[2], (weight - 0.5) * 2.0)
