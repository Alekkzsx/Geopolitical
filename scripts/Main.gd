extends Node2D

@onready var map_manager = $MapLayer

func _ready():
	print("GEOPOLITICAL SIMULATOR: Strategic Map Initialized.")
	
	# Initial Setup: Focus on the player's country (BRAZIL)
	# Waiting a frame to ensure get_viewport_rect() is accurate
	await get_tree().process_frame
	
	# Brazil: Lon -51.92, Lat -14.23
	map_manager.center_on_world_coord(-51.92, -14.23)
	
	# Initial Selection in Simulation
	WorldManager.select_country("BRA")
