extends Node2D

func _ready():
	print("Strategic Map Initialized.")
	# For prototype, select Brazil by default
	WorldManager.select_country("BRA")
