extends Node

signal country_selected(country_data)
signal tick(date_str)

var countries = {}
var selected_country_id = ""
var player_country_id = "BRA" # Dynamic player identification
var game_date = { "day": 1, "month": 1, "year": 2024 }
var timer = 0.0
var time_speed = 1.0

func _ready():
	load_data()

func load_data():
	var file = FileAccess.open("res://data/countries.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			countries = json.get_data()
		else:
			push_error("WorldManager: JSON parse error.")
	else:
		push_error("WorldManager: Database missing.")

func _process(delta):
	if time_speed > 0:
		timer += delta * time_speed
		if timer >= 1.0:
			timer = 0
			advance_time()

func advance_time():
	game_date.day += 1
	if game_date.day > 30:
		game_date.day = 1
		game_date.month += 1
		if game_date.month > 12:
			game_date.month = 1
			game_date.year += 1
	
	var date_str = "%02d/%02d/%d" % [game_date.day, game_date.month, game_date.year]
	emit_signal("tick", date_str)

func select_country(id):
	if not countries.has(id):
		# Create dynamic data for map countries not in core JSON
		countries[id] = {
			"name": id,
			"gdp": randf_range(0.1, 2.0),
			"population": randi_range(1, 50),
			"stability": randi_range(60, 90),
			"popularity": 50,
			"military_power": randi_range(5, 50),
			"inflation": randf_range(2.0, 8.0),
			"growth": randf_range(0.1, 4.0)
		}
		
	selected_country_id = id
	emit_signal("country_selected", countries[id])
