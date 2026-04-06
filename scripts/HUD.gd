extends CanvasLayer

@onready var date_label = $Header/Stats/Date
@onready var budget_label = $Header/Stats/Budget
@onready var gdp_label = $Header/Stats/GDP
@onready var country_info = $CountryInfo

# Map Mode Buttons
@onready var btn_eco = $Toolbar/Buttons/Economia
@onready var btn_soc = $Toolbar/Buttons/Social
@onready var btn_mil = $Toolbar/Buttons/Militar
@onready var btn_pol = $Toolbar/Buttons/Legislativo # Using for 'Political/Main' for now

func _ready():
	# Connect simulation signals
	WorldManager.tick.connect(_on_world_tick)
	WorldManager.country_selected.connect(_on_country_selected)
	
	# Connect Map Mode controls
	btn_eco.pressed.connect(_on_mode_button_pressed.bind("ECONOMY"))
	btn_soc.pressed.connect(_on_mode_button_pressed.bind("SOCIAL"))
	btn_mil.pressed.connect(_on_mode_button_pressed.bind("MILITARY"))
	btn_pol.pressed.connect(_on_mode_button_pressed.bind("POLITICAL"))

func _on_world_tick(date_str):
	date_label.text = date_str

func _on_country_selected(data):
	country_info.visible = true
	country_info.get_node("Name").text = data.name.to_upper()
	country_info.get_node("Stats").text = "GDP: " + str(data.gdp) + "T\nPopularity: " + str(data.popularity) + "%\nStability: " + str(data.stability) + "%"

func _on_mode_button_pressed(mode_name):
	# Access the MapModesManager (should be in MapLayer)
	var manager = get_tree().root.find_child("MapModesManager", true, false)
	
	if not manager:
		var map_layer = get_tree().root.find_child("MapLayer", true, false)
		if map_layer:
			if not map_layer.has_node("MapModesManager"):
				manager = load("res://scripts/MapModesManager.gd").new()
				manager.name = "MapModesManager"
				map_layer.add_child(manager)
			else:
				manager = map_layer.get_node("MapModesManager")

	if manager:
		match mode_name:
			"ECONOMY": manager.set_mode(1) # ECON mode index
			"SOCIAL": manager.set_mode(2)
			"MILITARY": manager.set_mode(3)
			"POLITICAL": manager.set_mode(0)
