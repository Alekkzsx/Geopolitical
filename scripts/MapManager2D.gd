extends Node2D

const MapModes = preload("res://scripts/MapModesManager.gd")

@export var zoom_step: float = 1.18
@export var min_zoom: float = 0.2
@export var max_zoom: float = 9.0
@export var lerp_speed: float = 10.0
@export var fit_world_margin: float = 0.92
@export var focus_screen_ratio: Vector2 = Vector2(0.34, 0.42)

const WORLD_WIDTH := 3600.0
const WORLD_HEIGHT := 1800.0
const HALF_WIDTH := WORLD_WIDTH * 0.5

var target_zoom: float = 1.0
var target_pos: Vector2 = Vector2.ZERO
var dragging: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO
var _fit_zoom: float = 0.5
var current_visual_mode: int = MapModes.Mode.POLITICAL
var current_alignment_reference: int = MapModes.AlignmentReference.PLAYER


func _ready():
	call_deferred("_initialize_view")
	call_deferred("_sync_renderer_state")


func _initialize_view():
	_fit_zoom = _calculate_fit_world_zoom()
	target_zoom = clampf(_fit_zoom, min_zoom, max_zoom)
	scale = Vector2.ONE * target_zoom
	target_pos = _viewport_center()
	position = target_pos


func center_on_world_coord(lon: float, lat: float):
	var world_point: Vector2 = Vector2(lon * 10.0, -lat * 10.0)
	_center_on_world_point(world_point, target_zoom)


func fit_world():
	_fit_zoom = _calculate_fit_world_zoom()
	target_zoom = clampf(_fit_zoom, min_zoom, max_zoom)
	target_pos = _viewport_center()


func focus_country(id: String):
	var country: Dictionary = WorldManager.get_map_country(id)
	if country.is_empty():
		return

	var bbox: Rect2 = country.get("bbox", Rect2())
	var bbox_center: Vector2 = country.get("bbox_center", bbox.position + (bbox.size * 0.5))
	var viewport_size: Vector2 = get_viewport_rect().size
	var focus_width: float = maxf(bbox.size.x, 80.0)
	var focus_height: float = maxf(bbox.size.y, 60.0)
	var zoom_x: float = (viewport_size.x * focus_screen_ratio.x) / focus_width
	var zoom_y: float = (viewport_size.y * focus_screen_ratio.y) / focus_height

	_fit_zoom = _calculate_fit_world_zoom()
	target_zoom = clampf(maxf(_fit_zoom, minf(zoom_x, zoom_y)), min_zoom, max_zoom)
	target_pos = _viewport_center() - bbox_center * target_zoom
	target_pos.x = _wrap_target_x_near(target_pos.x, position.x)


func set_visual_mode(mode: int):
	current_visual_mode = mode
	var renderer = _get_renderer()
	if renderer and renderer.has_method("set_visual_mode"):
		renderer.set_visual_mode(mode)


func get_visual_mode() -> int:
	return current_visual_mode


func set_alignment_reference(reference_mode: int):
	current_alignment_reference = reference_mode
	var renderer = _get_renderer()
	if renderer and renderer.has_method("set_alignment_reference"):
		renderer.set_alignment_reference(reference_mode)


func get_alignment_reference() -> int:
	return current_alignment_reference


func get_visual_context() -> Dictionary:
	var renderer = _get_renderer()
	if renderer and renderer.has_method("get_visual_context"):
		return renderer.get_visual_context()
	return {}


func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			last_mouse_pos = event.position

		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_mouse(zoom_step)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_mouse(1.0 / zoom_step)

	if event is InputEventMouseMotion and dragging:
		target_pos += event.position - last_mouse_pos
		last_mouse_pos = event.position


func _process(delta: float):
	var viewport_center: Vector2 = _viewport_center()
	var wrap_limit: float = HALF_WIDTH * maxf(target_zoom, 0.0001)

	if target_pos.x - viewport_center.x > wrap_limit:
		var shift: float = WORLD_WIDTH * target_zoom
		target_pos.x -= shift
		position.x -= shift
	elif target_pos.x - viewport_center.x < -wrap_limit:
		var shift_back: float = WORLD_WIDTH * target_zoom
		target_pos.x += shift_back
		position.x += shift_back

	position = position.lerp(target_pos, delta * lerp_speed)
	scale = scale.lerp(Vector2.ONE * target_zoom, delta * lerp_speed)


func _zoom_at_mouse(zoom_factor: float):
	var old_zoom: float = target_zoom
	var new_zoom: float = clampf(old_zoom * zoom_factor, maxf(min_zoom, _fit_zoom * 0.95), max_zoom)
	if is_equal_approx(old_zoom, new_zoom):
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var world_under_mouse: Vector2 = (mouse_pos - target_pos) / old_zoom
	target_zoom = new_zoom
	target_pos = mouse_pos - world_under_mouse * target_zoom


func _center_on_world_point(world_point: Vector2, zoom_value: float):
	target_zoom = clampf(zoom_value, min_zoom, max_zoom)
	target_pos = _viewport_center() - world_point * target_zoom


func _calculate_fit_world_zoom() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 0.5
	return minf(viewport_size.x / WORLD_WIDTH, viewport_size.y / WORLD_HEIGHT) * fit_world_margin


func _viewport_center() -> Vector2:
	return get_viewport_rect().size * 0.5


func _wrap_target_x_near(desired_x: float, reference_x: float) -> float:
	var wrapped: float = desired_x
	var scaled_world_width: float = WORLD_WIDTH * target_zoom
	while wrapped - reference_x > scaled_world_width * 0.5:
		wrapped -= scaled_world_width
	while wrapped - reference_x < -scaled_world_width * 0.5:
		wrapped += scaled_world_width
	return wrapped


func _sync_renderer_state():
	var renderer = _get_renderer()
	if renderer == null:
		return

	if renderer.has_method("set_visual_mode"):
		renderer.set_visual_mode(current_visual_mode)
	if renderer.has_method("set_alignment_reference"):
		renderer.set_alignment_reference(current_alignment_reference)


func _get_renderer():
	if has_node("Countries"):
		return $Countries
	return null
