extends Node2D

@export var zoom_speed: float = 0.2
@export var min_zoom: float = 0.1 # Expanded to see the whole world
@export var max_zoom: float = 15.0 # Expanded to see more terrain detail
@export var lerp_speed: float = 10.0

const WORLD_WIDTH = 3600.0
const HALF_WIDTH = 1800.0

var target_zoom: float = 1.0
var target_pos: Vector2 = Vector2.ZERO
var dragging: bool = false
var last_mouse_pos: Vector2

func _ready():
	# Ensuring target state is initialized correctly
	target_pos = position
	# Start with a slightly wider view to see more terrain
	target_zoom = 0.6 
	scale = Vector2(target_zoom, target_zoom)

func center_on_world_coord(lon: float, lat: float):
	var map_x = lon * 10.0
	var map_y = -lat * 10.0
	var viewport_center = get_viewport_rect().size / 2.0
	# We want (map_x, map_y) * target_zoom + position = viewport_center
	target_pos = viewport_center - Vector2(map_x, map_y) * target_zoom
	position = target_pos

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			last_mouse_pos = event.position
		
		# Pro Zooming: More responsive zoom factors
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_mouse(1.2)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_mouse(0.8)

	if event is InputEventMouseMotion and dragging:
		target_pos += (event.position - last_mouse_pos)
		last_mouse_pos = event.position

func _zoom_at_mouse(zoom_factor: float):
	var old_zoom = target_zoom
	target_zoom = clamp(target_zoom * zoom_factor, min_zoom, max_zoom)
	
	var mouse_pos = get_viewport().get_mouse_position()
	var direction = (target_pos - mouse_pos)
	target_pos = mouse_pos + direction * (target_zoom / old_zoom)

func _process(delta):
	# INFINITE HORIZONTAL WRAP
	var viewport_center = get_viewport_rect().size / 2.0
	var limit = HALF_WIDTH * target_zoom
	
	if target_pos.x - viewport_center.x > limit:
		var shift = WORLD_WIDTH * target_zoom
		target_pos.x -= shift
		position.x -= shift
	elif target_pos.x - viewport_center.x < -limit:
		var shift = WORLD_WIDTH * target_zoom
		target_pos.x += shift
		position.x += shift

	# SMOOTH LERP
	position = position.lerp(target_pos, delta * lerp_speed)
	scale = scale.lerp(Vector2(target_zoom, target_zoom), delta * lerp_speed)
