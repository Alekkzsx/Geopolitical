extends Node

# Signal when a country is selected
signal country_selected(country_data)
signal tick(date_str)

var countries = {}
var selected_country_id = ""
var game_date = { "day": 1, "month": 1, "year": 2024 }
var timer = 0.0
var time_speed = 1.0 # 0.0 is paused

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
			print("WorldManager: Loaded ", countries.size(), " countries.")
		else:
			push_error("WorldManager: Failed to parse JSON database.")
	else:
		push_error("WorldManager: Database not found.")

func _process(delta):
	if time_speed > 0:
		timer += delta * time_speed
		if timer >= 1.0: # One "day" every second at speed 1.0
			timer = 0
			advance_time()

func advance_time():
	game_date.day += 1
	if game_date.day > 30: # Simplified 30-day month
		game_date.day = 1
		game_date.month += 1
		if game_date.month > 12:
			game_date.month = 1
			game_date.year += 1
			run_yearly_simulation()
		run_monthly_simulation()
	
	var date_str = "%02d/%02d/%d" % [game_date.day, game_date.month, game_date.year]
	emit_signal("tick", date_str)

func run_monthly_simulation():
	# Simulation logic for ALL countries in memory
	for id in countries:
		var c = countries[id]
		# Ensure popularity field exists
		if not c.has("popularity"): c.popularity = 50
		if not c.has("growth"): c.growth = 2.0
		if not c.has("inflation"): c.inflation = 3.0
		
		# GDP growth (simplified)
		c.gdp += (c.gdp * (c.growth / 100.0)) / 12.0
		# Inflation impact
		if c.inflation > 5.0:
			c.popularity -= 0.1
		elif c.inflation < 2.0:
			c.popularity += 0.05
		c.popularity = clamp(c.popularity, 0, 100)

func run_yearly_simulation():
	print("WorldManager: Year passed: ", game_date.year)

func select_country(id):
	if not countries.has(id):
		# Create a placeholder if not in database
		print("WorldManager: Generating placeholder for ", id)
		countries[id] = {
			"name": id, # Better to get name from parser, but for now ID
			"gdp": randf_range(0.1, 5.0),
			"population": randi_range(5, 100),
			"stability": randi_range(50, 95),
			"popularity": 50,
			"military_power": randi_range(10, 80),
			"inflation": randf_range(2.0, 10.0),
			"growth": randf_range(-1.0, 5.0)
		}
		
	selected_country_id = id
	emit_signal("country_selected", countries[id])
