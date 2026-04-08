extends Node2D

const CountryLabelScript = preload("res://scripts/CountryLabel.gd")

const MODE_POLITICAL := 0
const MODE_ECONOMY := 1
const MODE_SOCIAL := 2
const MODE_MILITARY := 3

const COLOR_OCEAN := Color(0.024, 0.05, 0.082, 1.0)
const COLOR_LAND := Color(0.16, 0.19, 0.22, 0.9)
const COLOR_LAND_DISPUTED := Color(0.22, 0.18, 0.14, 0.9)
const COLOR_BORDER := Color(0.38, 0.45, 0.52, 0.72)
const COLOR_BORDER_PLAYER := Color(0.1, 0.62, 1.0, 1.0)
const COLOR_BORDER_SELECTED := Color(0.72, 0.92, 1.0, 1.0)
const COLOR_PLAYER_OVERLAY := Color(0.09, 0.48, 0.86, 0.2)
const COLOR_SELECTED_OVERLAY := Color(0.38, 0.72, 1.0, 0.34)
const COLOR_HOVER_OVERLAY := Color(0.92, 0.98, 1.0, 0.12)
const COLOR_CAPITAL := Color(0.93, 0.97, 1.0, 0.95)

const CLICK_PROXY_RADIUS := 18.0
const SMALL_COUNTRY_SIZE := 40.0

var current_mode: int = MODE_POLITICAL
var map_layer: Node2D

var country_views: Dictionary = {}

var _background_layer: Node2D
var _land_layer: Node2D
var _overlay_layer: Node2D
var _border_layer: Node2D
var _interaction_layer: Node2D
var _capital_layer: Node2D
var _label_layer: Node2D


func _ready():
	map_layer = get_parent()
	_setup_layers()
	_build_world()
	WorldManager.country_selected.connect(_on_country_selected)
	_refresh_all_country_visuals()


func _process(_delta: float):
	_update_labels_and_capitals()


func set_visual_mode(mode: int):
	current_mode = mode
	_refresh_all_country_visuals()


func get_country_map_data(id: String) -> Dictionary:
	return WorldManager.get_map_country(id)


func _setup_layers():
	for child in get_children():
		child.queue_free()

	_background_layer = Node2D.new()
	_background_layer.name = "Background"
	add_child(_background_layer)

	_land_layer = Node2D.new()
	_land_layer.name = "Land"
	add_child(_land_layer)

	_overlay_layer = Node2D.new()
	_overlay_layer.name = "Highlights"
	add_child(_overlay_layer)

	_border_layer = Node2D.new()
	_border_layer.name = "Borders"
	add_child(_border_layer)

	_interaction_layer = Node2D.new()
	_interaction_layer.name = "Interaction"
	add_child(_interaction_layer)

	_capital_layer = Node2D.new()
	_capital_layer.name = "Capitals"
	_capital_layer.z_index = 30
	add_child(_capital_layer)

	_label_layer = Node2D.new()
	_label_layer.name = "Labels"
	_label_layer.z_index = 40
	add_child(_label_layer)

	_build_background()


func _build_background():
	var ocean = Polygon2D.new()
	ocean.polygon = PackedVector2Array([
		Vector2(-4200.0, -2400.0),
		Vector2(4200.0, -2400.0),
		Vector2(4200.0, 2400.0),
		Vector2(-4200.0, 2400.0),
	])
	ocean.color = COLOR_OCEAN
	_background_layer.add_child(ocean)

	var texture = load("res://assets/maps/satellite_world.jpg")
	if texture:
		var sprite = Sprite2D.new()
		sprite.name = "SatelliteBackdrop"
		sprite.texture = texture
		sprite.centered = true
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.12)
		var target_scale = 3600.0 / float(texture.get_width())
		sprite.scale = Vector2.ONE * target_scale
		_background_layer.add_child(sprite)


func _build_world():
	country_views.clear()

	for id in WorldManager.map_countries.keys():
		var country: Dictionary = WorldManager.map_countries[id]
		_build_country(country)


func _build_country(country: Dictionary):
	var id: String = country.get("id", "")
	var polygons: Array = country.get("polygons", [])
	if id == "" or polygons.is_empty():
		return

	var view := {
		"id": id,
		"base_polygons": [],
		"overlay_polygons": [],
		"borders": [],
		"hover_count": 0,
	}

	for polygon_points in polygons:
		var base_polygon = Polygon2D.new()
		base_polygon.polygon = polygon_points
		_land_layer.add_child(base_polygon)
		view["base_polygons"].append(base_polygon)

		var overlay_polygon = Polygon2D.new()
		overlay_polygon.polygon = polygon_points
		overlay_polygon.color = Color(0.0, 0.0, 0.0, 0.0)
		_overlay_layer.add_child(overlay_polygon)
		view["overlay_polygons"].append(overlay_polygon)

		var border = Line2D.new()
		border.points = polygon_points
		border.default_color = COLOR_BORDER
		border.width = 1.1
		border.antialiased = true
		_border_layer.add_child(border)
		view["borders"].append(border)

		var area = Area2D.new()
		area.input_pickable = true
		var collision = CollisionPolygon2D.new()
		collision.polygon = polygon_points
		area.add_child(collision)
		_interaction_layer.add_child(area)

		area.input_event.connect(_on_country_input.bind(id))
		area.mouse_entered.connect(_on_country_mouse_entered.bind(id))
		area.mouse_exited.connect(_on_country_mouse_exited.bind(id))

	if _needs_click_proxy(country):
		var proxy = Area2D.new()
		proxy.input_pickable = true
		proxy.position = _get_click_proxy_position(country)

		var shape = CircleShape2D.new()
		shape.radius = CLICK_PROXY_RADIUS
		var collision_shape = CollisionShape2D.new()
		collision_shape.shape = shape
		proxy.add_child(collision_shape)
		_interaction_layer.add_child(proxy)

		proxy.input_event.connect(_on_country_input.bind(id))
		proxy.mouse_entered.connect(_on_country_mouse_entered.bind(id))
		proxy.mouse_exited.connect(_on_country_mouse_exited.bind(id))

	var label = Label.new()
	label.name = "Label_%s" % id
	label.top_level = true
	label.set_script(CountryLabelScript)
	label.text = country.get("display_name", id)
	label.visible = false
	_label_layer.add_child(label)
	view["label"] = label

	var capital_marker = Polygon2D.new()
	capital_marker.name = "Capital_%s" % id
	capital_marker.top_level = true
	capital_marker.polygon = PackedVector2Array([
		Vector2(0.0, -4.0),
		Vector2(4.0, 0.0),
		Vector2(0.0, 4.0),
		Vector2(-4.0, 0.0),
	])
	capital_marker.color = COLOR_CAPITAL
	capital_marker.visible = false
	_capital_layer.add_child(capital_marker)
	view["capital"] = capital_marker

	country_views[id] = view


func _refresh_all_country_visuals():
	for id in country_views.keys():
		_refresh_country_visual(id)


func _refresh_country_visual(id: String):
	var country: Dictionary = WorldManager.get_map_country(id)
	var view: Dictionary = country_views.get(id, {})
	if country.is_empty() or view.is_empty():
		return

	var base_fill := _get_base_fill_color(id, country)
	var overlay_fill := _get_overlay_fill_color(id, view)
	var border_color := _get_border_color(id, view)
	var border_width := _get_border_width(id, view)

	for polygon in view.get("base_polygons", []):
		polygon.color = base_fill

	for overlay_polygon in view.get("overlay_polygons", []):
		overlay_polygon.color = overlay_fill

	for border in view.get("borders", []):
		border.default_color = border_color
		border.width = border_width


func _get_base_fill_color(id: String, country: Dictionary) -> Color:
	var simulation: Dictionary = WorldManager.countries.get(id, {})
	var base = COLOR_LAND_DISPUTED if country.get("is_disputed", false) else COLOR_LAND

	match current_mode:
		MODE_POLITICAL:
			return base
		MODE_ECONOMY:
			if simulation.is_empty():
				return base.darkened(0.08)
			var growth = clamp(float(simulation.get("growth", 0.0)), -2.0, 8.0)
			var weight = _range_weight(-2.0, 8.0, growth)
			return _gradient([
				Color(0.48, 0.17, 0.12, 0.94),
				Color(0.71, 0.47, 0.16, 0.94),
				Color(0.78, 0.72, 0.28, 0.94),
				Color(0.25, 0.58, 0.31, 0.94),
			], weight)
		MODE_SOCIAL:
			if simulation.is_empty():
				return base.darkened(0.04)
			var stability = clamp(float(simulation.get("stability", 0.0)), 0.0, 100.0)
			var stability_weight = _range_weight(0.0, 100.0, stability)
			return _gradient([
				Color(0.43, 0.16, 0.18, 0.94),
				Color(0.69, 0.42, 0.18, 0.94),
				Color(0.71, 0.63, 0.24, 0.94),
				Color(0.26, 0.55, 0.42, 0.94),
			], stability_weight)
		MODE_MILITARY:
			if simulation.is_empty():
				return base.darkened(0.1)
			var military_power = clamp(float(simulation.get("military_power", 0.0)), 0.0, 100.0)
			var military_weight = _range_weight(0.0, 100.0, military_power)
			return _gradient([
				Color(0.16, 0.19, 0.22, 0.94),
				Color(0.18, 0.28, 0.4, 0.94),
				Color(0.22, 0.42, 0.56, 0.94),
				Color(0.42, 0.62, 0.72, 0.94),
			], military_weight)
		_:
			return base


func _get_overlay_fill_color(id: String, view: Dictionary) -> Color:
	var overlay := Color(0.0, 0.0, 0.0, 0.0)
	if id == WorldManager.player_country_id:
		overlay = COLOR_PLAYER_OVERLAY
	if id == WorldManager.selected_country_id:
		overlay = COLOR_SELECTED_OVERLAY
	if int(view.get("hover_count", 0)) > 0:
		overlay = overlay.lerp(COLOR_HOVER_OVERLAY, 0.6)
		overlay.a = min(overlay.a + COLOR_HOVER_OVERLAY.a, 0.42)
	return overlay


func _get_border_color(id: String, view: Dictionary) -> Color:
	if id == WorldManager.selected_country_id:
		return COLOR_BORDER_SELECTED
	if id == WorldManager.player_country_id:
		return COLOR_BORDER_PLAYER
	if int(view.get("hover_count", 0)) > 0:
		return COLOR_BORDER.lerp(Color(0.74, 0.86, 0.95, 0.9), 0.55)
	return COLOR_BORDER


func _get_border_width(id: String, view: Dictionary) -> float:
	var width := 1.05
	if id == WorldManager.player_country_id:
		width = 1.5
	if int(view.get("hover_count", 0)) > 0:
		width += 0.35
	if id == WorldManager.selected_country_id:
		width = 2.2
	return width


func _update_labels_and_capitals():
	var zoom := map_layer.scale.x
	var viewport_rect := get_viewport_rect()
	var candidates: Array = []
	var accepted_rects: Array = []

	for id in country_views.keys():
		var country: Dictionary = WorldManager.get_map_country(id)
		var view: Dictionary = country_views[id]
		var label: Label = view["label"]
		label.visible = false

		if not _should_show_label(id, country, zoom):
			continue

		var screen_pos := map_layer.to_global(country.get("label_anchor", Vector2.ZERO))
		if not viewport_rect.grow(80.0).has_point(screen_pos):
			continue

		var label_size := label.get_combined_minimum_size()
		candidates.append({
			"id": id,
			"score": _label_priority(id, country),
			"screen_pos": screen_pos,
			"size": label_size,
		})

	candidates.sort_custom(Callable(self, "_sort_label_candidates"))

	for candidate in candidates:
		var rect := Rect2(candidate["screen_pos"] - (candidate["size"] * 0.5), candidate["size"])
		var blocked := false
		for accepted in accepted_rects:
			if accepted.intersects(rect):
				blocked = true
				break
		if blocked:
			continue

		var label_view: Dictionary = country_views[candidate["id"]]
		var label_node: Label = label_view["label"]
		label_node.size = candidate["size"]
		label_node.global_position = candidate["screen_pos"] - (candidate["size"] * 0.5)
		label_node.modulate = _label_modulate(candidate["id"])
		label_node.visible = true
		accepted_rects.append(rect)

	for id in country_views.keys():
		_update_capital_visibility(id, zoom, viewport_rect)


func _update_capital_visibility(id: String, zoom: float, viewport_rect: Rect2):
	var country: Dictionary = WorldManager.get_map_country(id)
	var view: Dictionary = country_views[id]
	var capital_marker: Polygon2D = view["capital"]
	capital_marker.visible = false

	if not _should_show_capital(id, country, zoom):
		return

	var capital_coord: Vector2 = country.get("capital_coord", Vector2.ZERO)
	if capital_coord == Vector2.ZERO or str(country.get("capital_name", "")) == "":
		return

	var screen_pos := map_layer.to_global(capital_coord)
	if not viewport_rect.grow(40.0).has_point(screen_pos):
		return

	capital_marker.global_position = screen_pos
	capital_marker.color = COLOR_BORDER_SELECTED if id == WorldManager.selected_country_id else COLOR_CAPITAL
	capital_marker.visible = true


func _label_priority(id: String, country: Dictionary) -> float:
	var score := float(country.get("importance", 0.5))
	if id == WorldManager.player_country_id:
		score += 2.0
	if id == WorldManager.selected_country_id:
		score += 1.5
	return score


func _sort_label_candidates(a: Dictionary, b: Dictionary) -> bool:
	var score_a := float(a.get("score", 0.0))
	var score_b := float(b.get("score", 0.0))
	if not is_equal_approx(score_a, score_b):
		return score_a > score_b
	return str(a.get("id", "")) < str(b.get("id", ""))


func _label_modulate(id: String) -> Color:
	if id == WorldManager.selected_country_id:
		return Color(0.82, 0.96, 1.0, 1.0)
	if id == WorldManager.player_country_id:
		return Color(0.68, 0.86, 1.0, 0.98)
	return Color.WHITE


func _should_show_label(id: String, country: Dictionary, zoom: float) -> bool:
	if id == WorldManager.player_country_id or id == WorldManager.selected_country_id:
		return true

	var importance := float(country.get("importance", 0.5))
	if importance >= 0.86:
		return zoom >= 0.46
	if importance >= 0.72:
		return zoom >= 0.62
	if importance >= 0.55:
		return zoom >= 0.82
	return zoom >= 1.08


func _should_show_capital(id: String, country: Dictionary, zoom: float) -> bool:
	if str(country.get("capital_name", "")) == "":
		return false

	if id == WorldManager.player_country_id or id == WorldManager.selected_country_id:
		return zoom >= 0.58

	var importance := float(country.get("importance", 0.5))
	if importance >= 0.82:
		return zoom >= 0.72
	if importance >= 0.65:
		return zoom >= 0.94
	return zoom >= 1.2


func _needs_click_proxy(country: Dictionary) -> bool:
	var bbox: Rect2 = country.get("bbox", Rect2())
	return bbox.size.x <= SMALL_COUNTRY_SIZE or bbox.size.y <= SMALL_COUNTRY_SIZE


func _get_click_proxy_position(country: Dictionary) -> Vector2:
	var capital_coord: Vector2 = country.get("capital_coord", Vector2.ZERO)
	if capital_coord != Vector2.ZERO:
		return capital_coord
	return country.get("label_anchor", Vector2.ZERO)


func _gradient(colors: Array, weight: float) -> Color:
	if colors.is_empty():
		return COLOR_LAND
	if colors.size() == 1:
		return colors[0]

	var clamped_weight := clamp(weight, 0.0, 1.0)
	var scaled := clamped_weight * float(colors.size() - 1)
	var index := int(floor(scaled))
	var next_index := min(index + 1, colors.size() - 1)
	var local_weight := scaled - float(index)
	return colors[index].lerp(colors[next_index], local_weight)


func _range_weight(min_value: float, max_value: float, value: float) -> float:
	if is_equal_approx(min_value, max_value):
		return 0.0
	return clamp((value - min_value) / (max_value - min_value), 0.0, 1.0)


func _on_country_input(_viewport, event: InputEvent, _shape_idx: int, id: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		WorldManager.select_country(id)


func _on_country_mouse_entered(id: String):
	var view: Dictionary = country_views.get(id, {})
	if view.is_empty():
		return
	view["hover_count"] = int(view.get("hover_count", 0)) + 1
	country_views[id] = view
	_refresh_country_visual(id)


func _on_country_mouse_exited(id: String):
	var view: Dictionary = country_views.get(id, {})
	if view.is_empty():
		return
	view["hover_count"] = max(int(view.get("hover_count", 0)) - 1, 0)
	country_views[id] = view
	_refresh_country_visual(id)


func _on_country_selected(payload: Dictionary):
	var id := str(payload.get("id", ""))
	_refresh_all_country_visuals()
	if id != "" and country_views.has(id):
		_refresh_country_visual(id)
