extends Label

@export var base_font_size: int = 13


func _ready():
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", base_font_size)
	add_theme_constant_override("outline_size", 3)
	add_theme_color_override("font_color", Color(0.91, 0.95, 1.0, 0.95))
	add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.08, 0.9))
