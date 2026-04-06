extends CanvasLayer

@onready var date_label = $Header/Stats/Date
@onready var budget_label = $Header/Stats/Budget
@onready var gdp_label = $Header/Stats/GDP
@onready var unemploy_label = $Header/Stats/Unemployment

@onready var country_panel = $CountryInfo
@onready var country_name = $CountryInfo/Name
@onready var country_stats = $CountryInfo/Stats

func _ready():
	WorldManager.tick.connect(_on_world_manager_tick)
	WorldManager.country_selected.connect(_on_country_selected)
	country_panel.visible = false

func _on_world_manager_tick(date_str):
	date_label.text = date_str
	# Placeholder for stats update based on player country
	# In a real game, WorldManager would provide the current player's country stats
	pass

func _on_country_selected(data):
	if data.is_empty():
		country_panel.visible = false
	else:
		country_panel.visible = true
		country_name.text = data.name
		country_stats.text = "PIB: $%.1fT\nPopulação: %dM\nInflação: %.1f%%\nEstabilidade: %d%%" % [
			data.gdp, data.population, data.inflation, int(data.stability)
		]
