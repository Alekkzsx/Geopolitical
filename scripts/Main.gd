extends Node2D

@onready var map_manager = $MapLayer


func _ready():
	print("GEOPOLITICAL SIMULATOR: Strategic Map Initialized.")

	await get_tree().process_frame

	if map_manager.has_method("focus_country"):
		map_manager.focus_country(WorldManager.player_country_id)
	else:
		map_manager.center_on_world_coord(-51.92, -14.23)

	WorldManager.select_country(WorldManager.player_country_id)
