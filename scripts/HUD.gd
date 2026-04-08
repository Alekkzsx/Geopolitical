extends CanvasLayer

const MODE_POLITICAL := 0
const MODE_ECONOMY := 1
const MODE_SOCIAL := 2
const MODE_MILITARY := 3

@onready var date_label: Label = $Header/Stats/Date
@onready var budget_label: Label = $Header/Stats/Budget
@onready var gdp_label: Label = $Header/Stats/GDP
@onready var unemployment_label: Label = $Header/Stats/Unemployment
@onready var country_info: Panel = $CountryInfo
@onready var country_name_label: Label = $CountryInfo/Name
@onready var country_stats_label: Label = $CountryInfo/Stats

@onready var btn_eco: Button = $Toolbar/Buttons/Economia
@onready var btn_soc: Button = $Toolbar/Buttons/Social
@onready var btn_mil: Button = $Toolbar/Buttons/Militar
@onready var btn_pol: Button = $Toolbar/Buttons/Legislativo


func _ready():
	WorldManager.tick.connect(_on_world_tick)
	WorldManager.country_selected.connect(_on_country_selected)

	btn_eco.pressed.connect(_on_mode_button_pressed.bind(MODE_ECONOMY))
	btn_soc.pressed.connect(_on_mode_button_pressed.bind(MODE_SOCIAL))
	btn_mil.pressed.connect(_on_mode_button_pressed.bind(MODE_MILITARY))
	btn_pol.pressed.connect(_on_mode_button_pressed.bind(MODE_POLITICAL))

	date_label.text = "%02d/%02d/%d" % [WorldManager.game_date.day, WorldManager.game_date.month, WorldManager.game_date.year]
	_set_header_placeholders()
	country_info.visible = false


func _on_world_tick(date_str: String):
	date_label.text = date_str


func _on_country_selected(payload: Dictionary):
	country_info.visible = true
	country_name_label.text = str(payload.get("display_name", "Unknown"))

	var capital_name := str(payload.get("capital_name", ""))
	var lines := []
	if capital_name != "":
		lines.append("Capital: %s" % capital_name)

	if bool(payload.get("has_simulation_data", false)):
		var simulation: Dictionary = payload.get("simulation", {})
		lines.append("PIB: $%.1fT" % float(simulation.get("gdp", 0.0)))
		lines.append("Popularidade: %d%%" % int(simulation.get("popularity", 0)))
		lines.append("Estabilidade: %d%%" % int(simulation.get("stability", 0)))
		lines.append("Crescimento: %.1f%%" % float(simulation.get("growth", 0.0)))
		country_stats_label.text = "\n".join(lines)
		_update_header_from_simulation(simulation)
	else:
		lines.append("Dados estrategicos ainda indisponiveis.")
		lines.append("A identidade geografica do pais ja esta integrada ao novo mapa.")
		country_stats_label.text = "\n".join(lines)
		_set_header_placeholders()


func _on_mode_button_pressed(mode_value: int):
	var manager = get_tree().root.find_child("MapModesManager", true, false)
	if manager == null:
		var map_layer = get_tree().root.find_child("MapLayer", true, false)
		if map_layer:
			manager = load("res://scripts/MapModesManager.gd").new()
			manager.name = "MapModesManager"
			map_layer.add_child(manager)

	if manager:
		manager.set_mode(mode_value)


func _update_header_from_simulation(simulation: Dictionary):
	budget_label.text = "Inflacao: %.1f%%" % float(simulation.get("inflation", 0.0))
	gdp_label.text = "PIB: $%.1fT" % float(simulation.get("gdp", 0.0))
	unemployment_label.text = "Estabilidade: %d%%" % int(simulation.get("stability", 0))


func _set_header_placeholders():
	budget_label.text = "Inflacao: --"
	gdp_label.text = "PIB: --"
	unemployment_label.text = "Estabilidade: --"
