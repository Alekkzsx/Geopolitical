extends Node2D

@export var zoom_speed: float = 0.2
@export var min_zoom: float = 0.2
@export var max_zoom: float = 10.0
@export var lerp_speed: float = 10.0

var target_zoom: float = 1.0
var target_pos: Vector2 = Vector2.ZERO
var dragging: bool = false
var last_mouse_pos: Vector2

func _ready():
	target_pos = position
	target_zoom = scale.x

func _unhandled_input(event):
	# Pan with Right Mouse Button (Standard for Strategy) or Middle Mouse
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			last_mouse_pos = event.position
		
		# Pro Zooming: Zoom towards mouse
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_mouse(1.0 + zoom_speed)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_mouse(1.0 - zoom_speed)

	if event is InputEventMouseMotion and dragging:
		# Use the current scale to adjust pan speed
		target_pos += (event.position - last_mouse_pos) / scale.x
		last_mouse_pos = event.position

func _zoom_at_mouse(zoom_factor: float):
	# Get mouse position in local map coordinates before zoom
	var local_mouse = get_local_mouse_position()
	
	target_zoom = clamp(target_zoom * zoom_factor, min_zoom, max_zoom)
	
	# Adjust target position to zoom towards mouse
	# (Simplified for this manager, we just update target_zoom)
	pass

func _process(delta):
	# Smooth movement
	position = position.lerp(target_pos, delta * lerp_speed)
	scale = scale.lerp(Vector2(target_zoom, target_zoom), delta * lerp_speed)
