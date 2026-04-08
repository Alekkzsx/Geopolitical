extends Node2D

const CountryLabelScript = preload("res://scripts/CountryLabel.gd")
const MapModes = preload("res://scripts/MapModesManager.gd")

signal visual_context_changed(context)

const COLOR_OCEAN := Color(0.027, 0.051, 0.081, 1.0)
const COLOR_RELIEF_SHADOW := Color(0.0, 0.0, 0.0, 0.16)
const COLOR_LAND := Color(0.145, 0.168, 0.195, 0.98)
const COLOR_LAND_DISPUTED := Color(0.195, 0.17, 0.145, 0.98)
const COLOR_BORDER := Color(0.37, 0.43, 0.49, 0.72)
const COLOR_BORDER_PLAYER := Color(0.1, 0.62, 1.0, 1.0)
const COLOR_BORDER_SELECTED := Color(0.79, 0.93, 1.0, 1.0)
const COLOR_PLAYER_OVERLAY := Color(0.09, 0.48, 0.86, 0.2)
const COLOR_SELECTED_OVERLAY := Color(0.38, 0.72, 1.0, 0.34)
const COLOR_HOVER_OVERLAY := Color(0.95, 0.98, 1.0, 0.12)
const COLOR_SITE_CAPITAL := Color(0.94, 0.98, 1.0, 0.98)
const COLOR_SITE_CITY := Color(0.67, 0.79, 0.9, 0.92)

const CLICK_PROXY_RADIUS := 18.0
const SMALL_COUNTRY_SIZE := 40.0
const SITE_AREA_RADIUS_CAPITAL := 9.0
const SITE_AREA_RADIUS_CITY := 7.0
const SHADOW_OFFSET := Vector2(4.0, 4.0)

var current_mode: int = MapModes.Mode.POLITICAL
var current_alignment_reference: int = MapModes.AlignmentReference.PLAYER
var map_layer: Node2D

var country_views: Dictionary = {}
var site_views: Dictionary = {}

var _background_layer: Node2D
var _relief_layer: Node2D
var _land_layer: Node2D
var _overlay_layer: Node2D
var _border_layer: Node2D
var _interaction_layer: Node2D
var _site_layer: Node2D
var _site_interaction_layer: Node2D
var _site_label_layer: Node2D
var _label_layer: Node2D

var _tooltip_layer: CanvasLayer
var _tooltip_panel: PanelContainer
var _tooltip_label: Label

var _hovered_site_id: String = ""
var _last_context_signature: String = ""


func _ready():
	map_layer = get_parent()
	_setup_layers()
	_build_world()
	_build_sites()
	WorldManager.country_selected.connect(_on_country_selected)
	_refresh_all_country_visuals()
	_emit_visual_context_if_changed()


func _process(_delta: float):
	_update_country_labels_and_sites()
	_update_tooltip()


func set_visual_mode(mode: int):
	current_mode = mode
	_refresh_all_country_visuals()
	_emit_visual_context_if_changed()


func set_alignment_reference(reference_mode: int):
	current_alignment_reference = reference_mode
	_refresh_all_country_visuals()
	_emit_visual_context_if_changed()


func get_visual_context() -> Dictionary:
	var reference_id: String = WorldManager.get_alignment_reference_country_id(current_alignment_reference)
	var reference_name: String = WorldManager.get_map_country(reference_id).get("display_name", reference_id)
	var title: String = MapModes.mode_label(current_mode)
	if current_mode == MapModes.Mode.POLITICAL or current_mode == MapModes.Mode.ALIGNMENT:
		title = "%s | Ref: %s" % [title, reference_name]

	return {
		"mode": current_mode,
		"mode_label": MapModes.mode_label(current_mode),
		"legend_title": title,
		"legend_items": MapModes.legend_items_for_mode(current_mode),
		"alignment_reference": current_alignment_reference,
		"alignment_reference_label": MapModes.alignment_reference_label(current_alignment_reference),
		"alignment_reference_country_id": reference_id,
		"alignment_reference_country_name": reference_name,
	}


func _setup_layers():
	for child in get_children():
		child.queue_free()

	_background_layer = Node2D.new()
	_background_layer.name = "Background"
	add_child(_background_layer)

	_relief_layer = Node2D.new()
	_relief_layer.name = "Relief"
	add_child(_relief_layer)

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
	_interaction_layer.name = "CountryInteraction"
	add_child(_interaction_layer)

	_site_layer = Node2D.new()
	_site_layer.name = "Sites"
	_site_layer.z_index = 30
	add_child(_site_layer)

	_site_interaction_layer = Node2D.new()
	_site_interaction_layer.name = "SiteInteraction"
	_site_interaction_layer.z_index = 31
	add_child(_site_interaction_layer)

	_site_label_layer = Node2D.new()
	_site_label_layer.name = "SiteLabels"
	_site_label_layer.z_index = 35
	add_child(_site_label_layer)

	_label_layer = Node2D.new()
	_label_layer.name = "CountryLabels"
	_label_layer.z_index = 40
	add_child(_label_layer)

	_setup_tooltip_layer()
	_build_background()


func _setup_tooltip_layer():
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.name = "SiteTooltipLayer"
	_tooltip_layer.layer = 95
	add_child(_tooltip_layer)

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.025, 0.04, 0.94)
	panel_style.border_color = Color(0.35, 0.53, 0.68, 0.9)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	_tooltip_panel.add_theme_stylebox_override("panel", panel_style)
	_tooltip_layer.add_child(_tooltip_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_tooltip_panel.add_child(margin)

	_tooltip_label = Label.new()
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label.add_theme_font_size_override("font_size", 12)
	_tooltip_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.96))
	margin.add_child(_tooltip_label)


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
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.085)
		var target_scale: float = 3600.0 / float(texture.get_width())
		sprite.scale = Vector2.ONE * target_scale
		_background_layer.add_child(sprite)


func _build_world():
	country_views.clear()
	for id in WorldManager.map_countries.keys():
		_build_country(WorldManager.map_countries[id])


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
		var shadow_polygon = Polygon2D.new()
		shadow_polygon.polygon = polygon_points
		shadow_polygon.position = SHADOW_OFFSET
		shadow_polygon.color = COLOR_RELIEF_SHADOW
		_relief_layer.add_child(shadow_polygon)

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
		border.width = 1.08
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

		var proxy_shape = CircleShape2D.new()
		proxy_shape.radius = CLICK_PROXY_RADIUS
		var proxy_collision = CollisionShape2D.new()
		proxy_collision.shape = proxy_shape
		proxy.add_child(proxy_collision)
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

	country_views[id] = view


func _build_sites():
	site_views.clear()
	for site in WorldManager.get_map_sites():
		_build_site(site)


func _build_site(site: Dictionary):
	var id: String = str(site.get("id", ""))
	var site_type: String = str(site.get("type", "city"))
	if id == "":
		return

	var marker = Polygon2D.new()
	marker.name = "Marker_%s" % id
	marker.top_level = true
	marker.visible = false
	marker.polygon = _capital_marker_shape() if site_type == "capital" else _city_marker_shape()
	_site_layer.add_child(marker)

	var area = Area2D.new()
	area.name = "Area_%s" % id
	area.top_level = true
	area.input_pickable = true
	area.visible = false
	var shape = CircleShape2D.new()
	shape.radius = SITE_AREA_RADIUS_CAPITAL if site_type == "capital" else SITE_AREA_RADIUS_CITY
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = shape
	area.add_child(collision_shape)
	_site_interaction_layer.add_child(area)

	area.input_event.connect(_on_site_input.bind(id))
	area.mouse_entered.connect(_on_site_mouse_entered.bind(id))
	area.mouse_exited.connect(_on_site_mouse_exited.bind(id))

	var label = _create_site_label(str(site.get("name", "")))
	label.name = "SiteLabel_%s" % id
	label.visible = false
	_site_label_layer.add_child(label)

	site_views[id] = {
		"data": site,
		"marker": marker,
		"area": area,
		"label": label,
		"hovered": false,
		"screen_position": Vector2.ZERO,
	}


func _create_site_label(text: String) -> Label:
	var label = Label.new()
	label.top_level = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.95, 0.94))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.88))
	label.text = text
	return label


func _refresh_all_country_visuals():
	for id in country_views.keys():
		_refresh_country_visual(id)


func _refresh_country_visual(id: String):
	var country: Dictionary = WorldManager.get_map_country(id)
	var view: Dictionary = country_views.get(id, {})
	if country.is_empty() or view.is_empty():
		return

	var base_fill: Color = _get_base_fill_color(id, country)
	var overlay_fill: Color = _get_overlay_fill_color(id, view)
	var border_color: Color = _get_border_color(id, view)
	var border_width: float = _get_border_width(id, view)

	for polygon in view.get("base_polygons", []):
		polygon.color = base_fill

	for overlay_polygon in view.get("overlay_polygons", []):
		overlay_polygon.color = overlay_fill

	for border in view.get("borders", []):
		border.default_color = border_color
		border.width = border_width


func _get_base_fill_color(id: String, country: Dictionary) -> Color:
	var base_color: Color = COLOR_LAND_DISPUTED if country.get("is_disputed", false) else COLOR_LAND

	match current_mode:
		MapModes.Mode.POLITICAL:
			return base_color
		MapModes.Mode.POPULATION:
			return _comparison_color(float(country.get("population_est", 0.0)), [10000000.0, 30000000.0, 80000000.0, 200000000.0])
		MapModes.Mode.GDP:
			return _comparison_color(float(country.get("gdp_est", 0.0)), [50000000000.0, 250000000000.0, 1000000000000.0, 5000000000000.0])
		MapModes.Mode.GDP_PER_CAPITA:
			return _comparison_color(float(country.get("gdp_per_capita_est", 0.0)), [5000.0, 15000.0, 30000.0, 50000.0])
		MapModes.Mode.ALIGNMENT:
			return _alignment_fill_color(WorldManager.get_alignment_state(id, current_alignment_reference).get("key", "neutral"))
		_:
			return base_color


func _comparison_color(value: float, thresholds: Array) -> Color:
	var palette := [
		Color(0.176, 0.227, 0.283, 0.98),
		Color(0.21, 0.317, 0.405, 0.98),
		Color(0.276, 0.424, 0.474, 0.98),
		Color(0.44, 0.552, 0.39, 0.98),
		Color(0.68, 0.678, 0.314, 0.98),
	]
	var index: int = 0
	for threshold in thresholds:
		if value >= float(threshold):
			index += 1
	return palette[mini(index, palette.size() - 1)]


func _alignment_fill_color(key: String) -> Color:
	match key:
		"self":
			return Color(0.14, 0.38, 0.82, 0.98)
		"allied":
			return Color(0.2, 0.56, 0.45, 0.98)
		"friendly":
			return Color(0.35, 0.58, 0.45, 0.98)
		"competitive":
			return Color(0.61, 0.42, 0.22, 0.98)
		"adversarial":
			return Color(0.57, 0.2, 0.19, 0.98)
		_:
			return Color(0.31, 0.35, 0.39, 0.98)


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
		if current_mode == MapModes.Mode.POLITICAL:
			return _alignment_border_color(WorldManager.get_alignment_state(id, current_alignment_reference).get("key", "neutral"))
		return COLOR_BORDER.lerp(Color(0.74, 0.86, 0.95, 0.9), 0.55)
	return COLOR_BORDER


func _alignment_border_color(key: String) -> Color:
	match key:
		"self":
			return Color(0.42, 0.72, 1.0, 0.98)
		"allied":
			return Color(0.46, 0.86, 0.64, 0.96)
		"friendly":
			return Color(0.61, 0.84, 0.64, 0.94)
		"competitive":
			return Color(0.89, 0.72, 0.41, 0.96)
		"adversarial":
			return Color(0.94, 0.5, 0.46, 0.98)
		_:
			return Color(0.82, 0.88, 0.93, 0.92)


func _get_border_width(id: String, view: Dictionary) -> float:
	var width: float = 1.05
	if id == WorldManager.player_country_id:
		width = 1.5
	if int(view.get("hover_count", 0)) > 0:
		width += 0.35
	if id == WorldManager.selected_country_id:
		width = 2.2
	return width


func _update_country_labels_and_sites():
	var zoom: float = map_layer.scale.x
	var viewport_rect: Rect2 = get_viewport_rect()
	var accepted_rects: Array = []
	var country_candidates: Array = []
	var site_candidates: Array = []

	for id in country_views.keys():
		var country: Dictionary = WorldManager.get_map_country(id)
		var view: Dictionary = country_views[id]
		var label: Label = view["label"]
		label.visible = false

		if not _should_show_country_label(id, country, zoom):
			continue

		var label_anchor: Vector2 = country.get("label_anchor", Vector2.ZERO)
		var screen_pos: Vector2 = map_layer.to_global(label_anchor)
		if not viewport_rect.grow(80.0).has_point(screen_pos):
			continue

		var label_size: Vector2 = label.get_combined_minimum_size()
		country_candidates.append({
			"id": id,
			"score": _country_label_priority(id, country),
			"screen_pos": screen_pos,
			"size": label_size,
		})

	for site_id in site_views.keys():
		var site_view: Dictionary = site_views[site_id]
		var site: Dictionary = site_view["data"]
		var marker: Polygon2D = site_view["marker"]
		var area: Area2D = site_view["area"]
		var label_node: Label = site_view["label"]

		marker.visible = false
		area.visible = false
		area.input_pickable = false
		label_node.visible = false

		if not _should_show_site_marker(site, zoom):
			continue

		var screen_pos: Vector2 = map_layer.to_global(site.get("coord", Vector2.ZERO))
		if not viewport_rect.grow(60.0).has_point(screen_pos):
			continue

		marker.global_position = screen_pos
		marker.color = _site_marker_color(site, site_view)
		marker.visible = true

		area.global_position = screen_pos
		area.visible = true
		area.input_pickable = true

		site_view["screen_position"] = screen_pos
		site_views[site_id] = site_view

		if not _should_show_site_label(site, zoom):
			continue

		var label_size_site: Vector2 = label_node.get_combined_minimum_size()
		var label_offset_y: float = -19.0 if str(site.get("type", "city")) == "capital" else -14.0
		site_candidates.append({
			"id": site_id,
			"score": _site_label_priority(site),
			"screen_pos": screen_pos + Vector2(0.0, label_offset_y),
			"size": label_size_site,
		})

	country_candidates.sort_custom(Callable(self, "_sort_country_label_candidates"))
	for candidate in country_candidates:
		if _apply_label_candidate(candidate, accepted_rects, true):
			var country_id: String = str(candidate.get("id", ""))
			var country_label: Label = country_views[country_id]["label"]
			country_label.modulate = _country_label_modulate(country_id)

	site_candidates.sort_custom(Callable(self, "_sort_site_label_candidates"))
	for candidate in site_candidates:
		if _apply_label_candidate(candidate, accepted_rects, false):
			var site_id: String = str(candidate.get("id", ""))
			var site_label: Label = site_views[site_id]["label"]
			site_label.modulate = _site_label_modulate(site_views[site_id]["data"])

	if _hovered_site_id != "" and not site_views.has(_hovered_site_id):
		_hovered_site_id = ""


func _apply_label_candidate(candidate: Dictionary, accepted_rects: Array, is_country: bool) -> bool:
	var candidate_size: Vector2 = candidate.get("size", Vector2.ZERO)
	var candidate_screen_pos: Vector2 = candidate.get("screen_pos", Vector2.ZERO)
	var rect := Rect2(candidate_screen_pos - (candidate_size * 0.5), candidate_size)

	for accepted in accepted_rects:
		if accepted.intersects(rect):
			return false

	var id: String = str(candidate.get("id", ""))
	var label_node: Label = country_views[id]["label"] if is_country else site_views[id]["label"]
	label_node.size = candidate_size
	label_node.global_position = candidate_screen_pos - (candidate_size * 0.5)
	label_node.visible = true
	accepted_rects.append(rect)
	return true


func _country_label_priority(id: String, country: Dictionary) -> float:
	var score: float = float(country.get("importance", 0.5))
	if id == WorldManager.player_country_id:
		score += 2.0
	if id == WorldManager.selected_country_id:
		score += 1.5
	return score


func _site_label_priority(site: Dictionary) -> float:
	var score: float = float(site.get("importance", 0.5))
	if str(site.get("type", "city")) == "capital":
		score += 0.45
	if str(site.get("country_id", "")) == WorldManager.player_country_id:
		score += 0.25
	if str(site.get("country_id", "")) == WorldManager.selected_country_id:
		score += 0.4
	return score


func _sort_country_label_candidates(a: Dictionary, b: Dictionary) -> bool:
	var score_a: float = float(a.get("score", 0.0))
	var score_b: float = float(b.get("score", 0.0))
	if not is_equal_approx(score_a, score_b):
		return score_a > score_b
	return str(a.get("id", "")) < str(b.get("id", ""))


func _sort_site_label_candidates(a: Dictionary, b: Dictionary) -> bool:
	var score_a: float = float(a.get("score", 0.0))
	var score_b: float = float(b.get("score", 0.0))
	if not is_equal_approx(score_a, score_b):
		return score_a > score_b
	return str(a.get("id", "")) < str(b.get("id", ""))


func _country_label_modulate(id: String) -> Color:
	if id == WorldManager.selected_country_id:
		return Color(0.82, 0.96, 1.0, 1.0)
	if id == WorldManager.player_country_id:
		return Color(0.68, 0.86, 1.0, 0.98)
	return Color.WHITE


func _site_label_modulate(site: Dictionary) -> Color:
	var country_id: String = str(site.get("country_id", ""))
	if country_id == WorldManager.selected_country_id:
		return Color(0.86, 0.96, 1.0, 0.98)
	if country_id == WorldManager.player_country_id:
		return Color(0.74, 0.88, 1.0, 0.95)
	return Color(0.88, 0.92, 0.97, 0.92)


func _should_show_country_label(id: String, country: Dictionary, zoom: float) -> bool:
	if id == WorldManager.player_country_id or id == WorldManager.selected_country_id:
		return true

	var importance: float = float(country.get("importance", 0.5))
	if importance >= 0.86:
		return zoom >= 0.46
	if importance >= 0.72:
		return zoom >= 0.62
	if importance >= 0.55:
		return zoom >= 0.82
	return zoom >= 1.08


func _should_show_site_marker(site: Dictionary, zoom: float) -> bool:
	var site_type: String = str(site.get("type", "city"))
	var importance: float = float(site.get("importance", 0.5))
	var country_id: String = str(site.get("country_id", ""))

	if site_type == "capital":
		if country_id == WorldManager.player_country_id or country_id == WorldManager.selected_country_id:
			return zoom >= 0.54
		if importance >= 0.82:
			return zoom >= 0.68
		if importance >= 0.72:
			return zoom >= 0.82
		return zoom >= 0.96

	if importance >= 0.92:
		return zoom >= 0.92
	if importance >= 0.78:
		return zoom >= 1.08
	return zoom >= 1.28


func _should_show_site_label(site: Dictionary, zoom: float) -> bool:
	var site_type: String = str(site.get("type", "city"))
	var importance: float = float(site.get("importance", 0.5))

	if site_type == "capital":
		if importance >= 0.8:
			return zoom >= 0.96
		return zoom >= 1.08

	if importance >= 0.92:
		return zoom >= 1.16
	if importance >= 0.78:
		return zoom >= 1.32
	return zoom >= 1.52


func _site_marker_color(site: Dictionary, site_view: Dictionary) -> Color:
	var base: Color = COLOR_SITE_CAPITAL if str(site.get("type", "city")) == "capital" else COLOR_SITE_CITY
	var country_id: String = str(site.get("country_id", ""))
	if country_id == WorldManager.selected_country_id:
		base = base.lerp(COLOR_BORDER_SELECTED, 0.55)
	elif country_id == WorldManager.player_country_id:
		base = base.lerp(COLOR_BORDER_PLAYER, 0.45)

	if bool(site_view.get("hovered", false)):
		base = base.lightened(0.18)
	return base


func _update_tooltip():
	if _hovered_site_id == "" or not site_views.has(_hovered_site_id):
		_tooltip_panel.visible = false
		return

	var site_view: Dictionary = site_views[_hovered_site_id]
	if not bool(site_view.get("hovered", false)):
		_tooltip_panel.visible = false
		return

	var site: Dictionary = site_view["data"]
	var country: Dictionary = WorldManager.get_map_country(str(site.get("country_id", "")))
	var lines: Array = [
		str(site.get("name", "")),
		"%s | %s" % [_site_type_label(str(site.get("type", "city"))), country.get("display_name", str(site.get("country_id", "")))],
	]

	var population_est: float = float(site.get("population_est", 0.0))
	if population_est > 0.0:
		lines.append("Pop.: %s" % _format_compact_number(population_est))

	_tooltip_label.text = "\n".join(lines)
	var tooltip_size: Vector2 = _tooltip_panel.get_combined_minimum_size()
	_tooltip_panel.size = tooltip_size
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var viewport_size: Vector2 = get_viewport_rect().size
	var tooltip_pos: Vector2 = mouse_pos + Vector2(18.0, 18.0)

	if tooltip_pos.x + tooltip_size.x > viewport_size.x - 12.0:
		tooltip_pos.x = viewport_size.x - tooltip_size.x - 12.0
	if tooltip_pos.y + tooltip_size.y > viewport_size.y - 12.0:
		tooltip_pos.y = viewport_size.y - tooltip_size.y - 12.0

	_tooltip_panel.position = tooltip_pos
	_tooltip_panel.visible = true


func _site_type_label(site_type: String) -> String:
	return "Capital" if site_type == "capital" else "Cidade"


func _format_compact_number(value: float) -> String:
	if value >= 1000000000.0:
		return "%.1fB" % (value / 1000000000.0)
	if value >= 1000000.0:
		return "%.1fM" % (value / 1000000.0)
	if value >= 1000.0:
		return "%.1fK" % (value / 1000.0)
	return str(int(round(value)))


func _needs_click_proxy(country: Dictionary) -> bool:
	var bbox: Rect2 = country.get("bbox", Rect2())
	return bbox.size.x <= SMALL_COUNTRY_SIZE or bbox.size.y <= SMALL_COUNTRY_SIZE


func _get_click_proxy_position(country: Dictionary) -> Vector2:
	var capital_coord: Vector2 = country.get("capital_coord", Vector2.ZERO)
	if capital_coord != Vector2.ZERO:
		return capital_coord
	return country.get("label_anchor", Vector2.ZERO)


func _capital_marker_shape() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -4.5),
		Vector2(4.5, 0.0),
		Vector2(0.0, 4.5),
		Vector2(-4.5, 0.0),
	])


func _city_marker_shape() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -3.4),
		Vector2(2.4, -2.4),
		Vector2(3.4, 0.0),
		Vector2(2.4, 2.4),
		Vector2(0.0, 3.4),
		Vector2(-2.4, 2.4),
		Vector2(-3.4, 0.0),
		Vector2(-2.4, -2.4),
	])


func _emit_visual_context_if_changed():
	var context: Dictionary = get_visual_context()
	var signature: String = "%s|%s|%s" % [
		str(context.get("mode", current_mode)),
		str(context.get("alignment_reference", current_alignment_reference)),
		str(context.get("alignment_reference_country_id", "")),
	]
	if signature == _last_context_signature:
		return

	_last_context_signature = signature
	emit_signal("visual_context_changed", context)


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


func _on_site_input(_viewport, event: InputEvent, _shape_idx: int, site_id: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not site_views.has(site_id):
			return
		var site: Dictionary = site_views[site_id]["data"]
		WorldManager.select_country(str(site.get("country_id", "")))


func _on_site_mouse_entered(site_id: String):
	if not site_views.has(site_id):
		return
	var site_view: Dictionary = site_views[site_id]
	site_view["hovered"] = true
	site_views[site_id] = site_view
	_hovered_site_id = site_id


func _on_site_mouse_exited(site_id: String):
	if not site_views.has(site_id):
		return
	var site_view: Dictionary = site_views[site_id]
	site_view["hovered"] = false
	site_views[site_id] = site_view
	if _hovered_site_id == site_id:
		_hovered_site_id = ""


func _on_country_selected(_payload: Dictionary):
	_refresh_all_country_visuals()
	_emit_visual_context_if_changed()
