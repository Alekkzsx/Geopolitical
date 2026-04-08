extends CanvasLayer

const MapModes = preload("res://scripts/MapModesManager.gd")

@onready var date_label: Label = $Header/Stats/Date
@onready var budget_label: Label = $Header/Stats/Budget
@onready var gdp_label: Label = $Header/Stats/GDP
@onready var unemployment_label: Label = $Header/Stats/Unemployment
@onready var country_info: Panel = $CountryInfo
@onready var country_name_label: Label = $CountryInfo/Name
@onready var country_stats_label: Label = $CountryInfo/Stats
@onready var toolbar: Panel = $Toolbar
@onready var btn_eco: Button = $Toolbar/Buttons/Economia
@onready var btn_soc: Button = $Toolbar/Buttons/Social
@onready var btn_mil: Button = $Toolbar/Buttons/Militar
@onready var btn_pol: Button = $Toolbar/Buttons/Legislativo

var map_layer: Node
var map_renderer: Node
var selected_payload: Dictionary = {}

var map_controls_panel: Panel
var legend_title_label: Label
var legend_items_label: Label
var reference_selector: OptionButton
var reference_status_label: Label
var mode_buttons: Dictionary = {}


func _ready():
	map_layer = get_tree().root.find_child("MapLayer", true, false)
	map_renderer = get_tree().root.find_child("Countries", true, false)

	WorldManager.tick.connect(_on_world_tick)
	WorldManager.country_selected.connect(_on_country_selected)
	if map_renderer and map_renderer.has_signal("visual_context_changed"):
		map_renderer.visual_context_changed.connect(_on_visual_context_changed)

	date_label.text = "%02d/%02d/%d" % [WorldManager.game_date.day, WorldManager.game_date.month, WorldManager.game_date.year]
	_prepare_country_sheet()
	_create_map_controls()
	_disable_toolbar_as_primary_map_control()
	_set_header_placeholders()
	country_info.visible = false
	_refresh_map_controls_state()


func _prepare_country_sheet():
	country_info.offset_left = -360.0
	country_info.offset_right = -20.0
	country_info.offset_top = 70.0
	country_info.offset_bottom = 395.0
	country_name_label.text = ""
	country_stats_label.offset_right = 330.0
	country_stats_label.offset_bottom = 300.0
	country_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _create_map_controls():
	map_controls_panel = Panel.new()
	map_controls_panel.name = "MapControls"
	map_controls_panel.anchor_left = 1.0
	map_controls_panel.anchor_top = 1.0
	map_controls_panel.anchor_right = 1.0
	map_controls_panel.anchor_bottom = 1.0
	map_controls_panel.offset_left = -360.0
	map_controls_panel.offset_top = -330.0
	map_controls_panel.offset_right = -20.0
	map_controls_panel.offset_bottom = -78.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.01, 0.02, 0.04, 0.92)
	panel_style.border_color = Color(0.17, 0.39, 0.59, 0.96)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	map_controls_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(map_controls_panel)

	var margin := MarginContainer.new()
	margin.anchors_preset = Control.PRESET_FULL_RECT
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	map_controls_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.anchors_preset = Control.PRESET_FULL_RECT
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Map Controls"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0, 1.0))
	root.add_child(title)

	var modes_grid := GridContainer.new()
	modes_grid.columns = 2
	modes_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes_grid.add_theme_constant_override("h_separation", 8)
	modes_grid.add_theme_constant_override("v_separation", 8)
	root.add_child(modes_grid)

	for mode in MapModes.MODE_SEQUENCE:
		var button := Button.new()
		button.text = MapModes.mode_button_label(mode)
		button.toggle_mode = true
		button.flat = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_map_mode_pressed.bind(mode))
		modes_grid.add_child(button)
		mode_buttons[mode] = button

	var reference_title := Label.new()
	reference_title.text = "Referencia de alinhamento"
	reference_title.add_theme_color_override("font_color", Color(0.71, 0.82, 0.92, 0.95))
	root.add_child(reference_title)

	reference_selector = OptionButton.new()
	reference_selector.add_item(MapModes.alignment_reference_label(MapModes.AlignmentReference.PLAYER), MapModes.AlignmentReference.PLAYER)
	reference_selector.add_item(MapModes.alignment_reference_label(MapModes.AlignmentReference.SELECTED), MapModes.AlignmentReference.SELECTED)
	reference_selector.item_selected.connect(_on_alignment_reference_selected)
	root.add_child(reference_selector)

	reference_status_label = Label.new()
	reference_status_label.add_theme_font_size_override("font_size", 11)
	reference_status_label.add_theme_color_override("font_color", Color(0.63, 0.74, 0.85, 0.9))
	root.add_child(reference_status_label)

	var separator := HSeparator.new()
	root.add_child(separator)

	legend_title_label = Label.new()
	legend_title_label.add_theme_font_size_override("font_size", 16)
	legend_title_label.add_theme_color_override("font_color", Color(0.84, 0.93, 1.0, 0.98))
	root.add_child(legend_title_label)

	legend_items_label = Label.new()
	legend_items_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend_items_label.add_theme_color_override("font_color", Color(0.8, 0.86, 0.92, 0.96))
	root.add_child(legend_items_label)


func _disable_toolbar_as_primary_map_control():
	toolbar.modulate = Color(1.0, 1.0, 1.0, 0.45)
	for button in [btn_eco, btn_soc, btn_mil, btn_pol]:
		button.disabled = true
		button.tooltip_text = "As camadas do mapa agora ficam no painel inferior direito."


func _on_world_tick(date_str: String):
	date_label.text = date_str


func _on_country_selected(payload: Dictionary):
	selected_payload = payload
	country_info.visible = true
	_refresh_country_sheet()
	_update_header_from_payload(payload)
	_refresh_map_controls_state()


func _on_visual_context_changed(_context: Dictionary):
	_refresh_map_controls_state()
	if not selected_payload.is_empty():
		_refresh_country_sheet()


func _on_map_mode_pressed(mode_value: int):
	if map_layer and map_layer.has_method("set_visual_mode"):
		map_layer.set_visual_mode(mode_value)
	_refresh_map_controls_state()


func _on_alignment_reference_selected(index: int):
	if map_layer and map_layer.has_method("set_alignment_reference"):
		map_layer.set_alignment_reference(index)
	_refresh_map_controls_state()
	if not selected_payload.is_empty():
		_refresh_country_sheet()


func _refresh_map_controls_state():
	var context: Dictionary = {}
	if map_layer and map_layer.has_method("get_visual_context"):
		context = map_layer.get_visual_context()

	var active_mode: int = int(context.get("mode", MapModes.Mode.POLITICAL))
	for mode in mode_buttons.keys():
		var button: Button = mode_buttons[mode]
		var is_active: bool = int(mode) == active_mode
		button.button_pressed = is_active
		button.flat = not is_active
		button.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_active else Color(0.86, 0.9, 0.95, 0.9)

	var selected_reference: int = int(context.get("alignment_reference", MapModes.AlignmentReference.PLAYER))
	if reference_selector.item_count > selected_reference:
		reference_selector.select(selected_reference)

	var reference_name: String = str(context.get("alignment_reference_country_name", ""))
	var reference_status: String = "Referencia ativa: %s" % reference_name
	if selected_reference == MapModes.AlignmentReference.SELECTED:
		var effective_reference_id: String = str(context.get("alignment_reference_country_id", ""))
		if effective_reference_id == WorldManager.player_country_id and WorldManager.selected_country_id == WorldManager.player_country_id:
			reference_status = "Referencia ativa: %s (fallback)" % reference_name
	reference_status_label.text = reference_status

	legend_title_label.text = str(context.get("legend_title", "Political"))
	legend_items_label.text = _format_legend_items(context.get("legend_items", []))


func _refresh_country_sheet():
	if selected_payload.is_empty():
		country_info.visible = false
		return

	var map_data: Dictionary = selected_payload.get("map", {})
	var country_id: String = str(selected_payload.get("id", ""))
	var display_name: String = str(selected_payload.get("display_name", country_id))
	var iso_a2: String = str(map_data.get("iso_a2", "--"))
	var capital_name: String = str(selected_payload.get("capital_name", ""))

	country_name_label.text = display_name

	var lines: Array = [
		"ISO: %s / %s" % [iso_a2, country_id],
		"Capital: %s" % (capital_name if capital_name != "" else "--"),
		"Populacao: %s" % _format_population(float(map_data.get("population_est", 0.0))),
		"PIB: %s" % _format_currency(float(map_data.get("gdp_est", 0.0))),
		"PIB per capita: %s" % _format_currency(float(map_data.get("gdp_per_capita_est", 0.0))),
		"Alinhamento c/ Jogador: %s" % _format_alignment(map_data.get("alignment_to_player", {})),
	]

	if WorldManager.selected_country_id != "" and WorldManager.selected_country_id != WorldManager.player_country_id:
		var alignment_selected: Dictionary = WorldManager.get_alignment_state_between(country_id, WorldManager.selected_country_id)
		lines.append("Alinhamento c/ Selecionado: %s" % _format_alignment(alignment_selected))

	lines.append("")
	lines.append("Simulacao")

	if bool(selected_payload.get("has_simulation_data", false)):
		var simulation: Dictionary = selected_payload.get("simulation", {})
		lines.append("Popularidade: %d%%" % int(simulation.get("popularity", 0)))
		lines.append("Estabilidade: %d%%" % int(simulation.get("stability", 0)))
		lines.append("Crescimento: %.1f%%" % float(simulation.get("growth", 0.0)))
		lines.append("Poder militar: %d%%" % int(simulation.get("military_power", 0)))
	else:
		lines.append("Dados estrategicos ainda indisponiveis.")

	country_stats_label.text = "\n".join(lines)


func _update_header_from_payload(payload: Dictionary):
	var map_data: Dictionary = payload.get("map", {})
	var capital_name: String = str(payload.get("capital_name", ""))
	budget_label.text = "Pop.: %s" % _format_population(float(map_data.get("population_est", 0.0)))
	gdp_label.text = "PIB: %s" % _format_currency(float(map_data.get("gdp_est", 0.0)))
	unemployment_label.text = "Capital: %s" % (capital_name if capital_name != "" else "--")


func _set_header_placeholders():
	budget_label.text = "Pop.: --"
	gdp_label.text = "PIB: --"
	unemployment_label.text = "Capital: --"


func _format_population(value: float) -> String:
	if value >= 1000000000.0:
		return "%.2fB" % (value / 1000000000.0)
	if value >= 1000000.0:
		return "%.1fM" % (value / 1000000.0)
	if value >= 1000.0:
		return "%.1fK" % (value / 1000.0)
	if value <= 0.0:
		return "--"
	return str(int(round(value)))


func _format_currency(value: float) -> String:
	if value >= 1000000000000.0:
		return "US$ %.2fT" % (value / 1000000000000.0)
	if value >= 1000000000.0:
		return "US$ %.1fB" % (value / 1000000000.0)
	if value >= 1000000.0:
		return "US$ %.1fM" % (value / 1000000.0)
	if value <= 0.0:
		return "--"
	return "US$ %d" % int(round(value))


func _format_alignment(state: Variant) -> String:
	if state is Dictionary and not state.is_empty():
		return str(state.get("label", "Neutral"))
	return "Neutral"


func _format_legend_items(items: Variant) -> String:
	if not (items is Array):
		return ""

	var lines: Array = []
	for item in items:
		lines.append("- %s" % str(item))
	return "\n".join(lines)
