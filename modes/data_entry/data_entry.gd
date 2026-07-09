extends Control

signal navigate_requested(screen_name: StringName)

const SaveManagerScript := preload("res://data/saving/save_manager.gd")
const CompetitionModel := preload("res://data/models/competition.gd")
const TeamModel := preload("res://data/models/team.gd")
const PlayerModel := preload("res://data/models/player.gd")
const GameModel := preload("res://data/models/game.gd")
const RulesetModel := preload("res://data/models/ruleset.gd")

@onready var entity_tabs: TabBar = %EntityTabs
@onready var search_field: LineEdit = %SearchField
@onready var entity_list: ItemList = %EntityList
@onready var editor_title: Label = %EditorTitle
@onready var form_grid: GridContainer = %FormGrid
@onready var warning_label: Label = %WarningLabel
@onready var status_label: Label = %StatusLabel
@onready var new_button: Button = %NewButton
@onready var save_button: Button = %SaveButton
@onready var delete_button: Button = %DeleteButton
@onready var validate_button: Button = %ValidateButton

var repository: DataRepository
var selected_type := "competitions"
var selected_id := ""
var fields: Dictionary = {}
var id_seed := 1

func _ready() -> void:
	_load_or_create_repository()
	_ensure_standard_ruleset()
	_connect_signals()
	_refresh_list()
	_select_first_entity()

func _connect_signals() -> void:
	entity_tabs.tab_changed.connect(_on_tab_changed)
	search_field.text_changed.connect(func(_text: String) -> void: _refresh_list())
	entity_list.item_selected.connect(_on_entity_selected)
	new_button.pressed.connect(_on_new_pressed)
	save_button.pressed.connect(_on_save_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	validate_button.pressed.connect(_on_validate_pressed)

func _load_or_create_repository() -> void:
	repository = SaveManagerScript.load_project()
	if repository == null:
		repository = SaveManagerScript.new_project()
		status_label.text = "Started a new local project."
	else:
		status_label.text = "Loaded saved project."

func _ensure_standard_ruleset() -> void:
	if repository.find_entity_by_id(Ruleset.DEFAULT_ID, "rulesets") == null:
		repository.add_ruleset(RulesetModel.new())

func _on_tab_changed(tab: int) -> void:
	selected_type = ["competitions", "teams", "players", "games"][tab]
	selected_id = ""
	_refresh_list()
	_select_first_entity()

func _on_entity_selected(index: int) -> void:
	selected_id = str(entity_list.get_item_metadata(index))
	_show_editor(_selected_entity())

func _on_new_pressed() -> void:
	var entity: Variant = _make_new_entity(selected_type)
	selected_id = entity.id
	_show_editor(entity)
	status_label.text = "Editing new %s. Save to add it." % _singular(selected_type)

func _on_save_pressed() -> void:
	var entity: Variant = _selected_entity()
	var is_new := false
	if entity == null:
		entity = _make_new_entity(selected_type)
		is_new = true
	_apply_fields_to_entity(entity)
	var warnings := _validate_entity(entity)
	warning_label.text = "\n".join(warnings)
	if is_new:
		_add_entity(entity)
	_rebuild_relationships()
	var err := SaveManagerScript.save_project(repository)
	status_label.text = "Saved." if err == OK else "Save failed: %d" % err
	selected_id = entity.id
	_refresh_list()
	_select_id(selected_id)

func _on_delete_pressed() -> void:
	if selected_id.is_empty():
		return
	_remove_selected_entity()
	_rebuild_relationships()
	SaveManagerScript.save_project(repository)
	selected_id = ""
	_refresh_list()
	_select_first_entity()
	status_label.text = "Deleted and saved."

func _on_validate_pressed() -> void:
	var warnings := PackedStringArray()
	for collection in [repository.competitions, repository.teams, repository.players, repository.games]:
		for entity in collection:
			warnings.append_array(entity.validate())
	warnings.append_array(repository.validate_broken_references())
	warnings.append_array(_manual_validation_warnings())
	warning_label.text = "No validation warnings." if warnings.is_empty() else "\n".join(warnings)
	status_label.text = "Validation complete."

func _refresh_list() -> void:
	entity_list.clear()
	var filter := search_field.text.strip_edges().to_lower()
	for entity in _current_collection():
		var label := _entity_label(entity)
		if filter.is_empty() or label.to_lower().contains(filter) or entity.id.to_lower().contains(filter):
			entity_list.add_item(label)
			entity_list.set_item_metadata(entity_list.item_count - 1, entity.id)

func _select_first_entity() -> void:
	if entity_list.item_count > 0:
		entity_list.select(0)
		_on_entity_selected(0)
	else:
		_show_editor(null)

func _select_id(entity_id: String) -> void:
	for i in range(entity_list.item_count):
		if entity_list.get_item_metadata(i) == entity_id:
			entity_list.select(i)
			break

func _show_editor(entity: Variant) -> void:
	for child in form_grid.get_children():
		child.queue_free()
	fields.clear()
	warning_label.text = ""
	editor_title.text = "No %s selected" % _singular(selected_type) if entity == null else "Edit %s" % _entity_label(entity)
	if entity == null:
		return
	for spec in _field_specs(selected_type):
		_add_field(spec[0], spec[1], _get_value(entity, spec[0]), spec[2] if spec.size() > 2 else [])
	warning_label.text = "\n".join(_validate_entity(entity))

func _add_field(property: String, label_text: String, value: Variant, options: Array = []) -> void:
	var label := Label.new()
	label.text = label_text
	form_grid.add_child(label)
	var control: Control
	if not options.is_empty():
		var option := OptionButton.new()
		option.add_item("")
		for item in options:
			option.add_item(item)
		option.select(max(0, options.find(str(value)) + 1))
		control = option
	else:
		var edit := LineEdit.new()
		edit.text = _stringify_value(value)
		control = edit
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_grid.add_child(control)
	fields[property] = control

func _field_specs(type: String) -> Array:
	match type:
		"competitions": return [["id", "ID"], ["name", "Name"], ["year", "Year"], ["location", "Location"], ["ruleset_id", "Ruleset ID", _ids(repository.rulesets)], ["start_date", "Start Date"], ["end_date", "End Date"], ["notes", "Notes"]]
		"teams": return [["id", "ID"], ["competition_id", "Competition", _ids(repository.competitions)], ["name", "Team Name"], ["school_name", "School"], ["region", "Region"], ["short_name", "Short Name"], ["abbreviation", "Abbreviation"], ["coach_name", "Coach"], ["colors", "Colors (comma separated)"], ["notes", "Notes"]]
		"players": return [["id", "ID"], ["team_id", "Team", _ids(repository.teams)], ["display_name", "Display Name"], ["first_name", "First Name"], ["last_name", "Last Name"], ["japanese_name", "Japanese Name"], ["kana_reading", "Kana"], ["jersey_number", "Jersey #"], ["grade", "Grade"], ["positions", "Positions (comma separated)"], ["throws_hand", "Throws", ["Unknown", "Left", "Right", "Switch"]], ["bats", "Bats", ["Unknown", "Left", "Right", "Switch"]], ["notes", "Notes"]]
		"games": return [["id", "ID"], ["competition_id", "Competition", _ids(repository.competitions)], ["home_team_id", "Home Team", _ids(repository.teams)], ["away_team_id", "Away Team", _ids(repository.teams)], ["date", "Date"], ["start_time", "Start Time"], ["venue", "Venue"], ["round", "Round"], ["game_number", "Game #"], ["status", "Status", ["Scheduled", "In Progress", "Final", "Suspended", "Cancelled"]], ["notes", "Notes"]]
	return []

func _apply_fields_to_entity(entity: Variant) -> void:
	for property in fields:
		var value := _field_text(fields[property]).strip_edges()
		match property:
			"year": entity.set(property, int(value))
			"colors", "positions": entity.set(property, _csv_to_array(value))
			_: entity.set(property, value)

func _make_new_entity(type: String) -> Variant:
	id_seed += 1
	var id := "%s_%d" % [_singular(type), Time.get_unix_time_from_system() + id_seed]
	match type:
		"competitions": return CompetitionModel.new(id, "New Competition")
		"teams": return TeamModel.new(id, _first_id(repository.competitions), "New Team")
		"players": return PlayerModel.new(id, _first_id(repository.teams), "New Player")
		"games":
			var game := GameModel.new(id, _first_id(repository.competitions))
			if repository.teams.size() > 0: game.home_team_id = repository.teams[0].id
			if repository.teams.size() > 1: game.away_team_id = repository.teams[1].id
			return game
	return null

func _add_entity(entity: Variant) -> void:
	match selected_type:
		"competitions": repository.add_competition(entity)
		"teams": repository.add_team(entity)
		"players": repository.add_player(entity)
		"games": repository.add_game(entity)

func _remove_selected_entity() -> void:
	for collection in [repository.competitions, repository.teams, repository.players, repository.games]:
		for i in range(collection.size() - 1, -1, -1):
			if collection[i].id == selected_id:
				collection.remove_at(i)

func _rebuild_relationships() -> void:
	for competition in repository.competitions:
		competition.team_ids.clear(); competition.game_ids.clear()
	for team in repository.teams:
		team.roster_player_ids.clear(); team.game_ids.clear()
	for team in repository.teams:
		var competition: Competition = repository.find_entity_by_id(team.competition_id, "competitions")
		if competition != null: competition.add_team_id(team.id)
	for player in repository.players:
		var team: Team = repository.find_entity_by_id(player.team_id, "teams")
		if team != null: team.add_player_id(player.id)
	for game in repository.games:
		var competition: Competition = repository.find_entity_by_id(game.competition_id, "competitions")
		if competition != null: competition.add_game_id(game.id)
		for team_id in [game.home_team_id, game.away_team_id]:
			var team: Team = repository.find_entity_by_id(team_id, "teams")
			if team != null: team.add_game_id(game.id)

func _manual_validation_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var team_names := {}
	for team in repository.teams:
		var key := "%s|%s" % [team.competition_id, team.name.to_lower()]
		if team_names.has(key): warnings.append("Duplicate team name '%s' in competition %s." % [team.name, team.competition_id])
		team_names[key] = true
	var jerseys := {}
	for player in repository.players:
		if player.jersey_number.strip_edges().is_empty(): continue
		var key := "%s|%s" % [player.team_id, player.jersey_number]
		if jerseys.has(key): warnings.append("Duplicate jersey #%s on team %s." % [player.jersey_number, player.team_id])
		jerseys[key] = true
	return warnings

func _selected_entity() -> Variant: return repository.find_entity_by_id(selected_id, selected_type)
func _current_collection() -> Array: return repository.get(selected_type)
func _ids(items: Array) -> Array: return items.map(func(item): return item.id)
func _first_id(items: Array) -> String: return "" if items.is_empty() else items[0].id
func _singular(type: String) -> String: return type.trim_suffix("s")
func _field_text(control: Control) -> String: return control.text if control is LineEdit else control.get_item_text(control.selected)
func _csv_to_array(text: String) -> Array[String]:
	var output: Array[String] = []
	for part in text.split(",", false): output.append(part.strip_edges())
	return output
func _stringify_value(value: Variant) -> String: return ", ".join(value) if value is Array else str(value)
func _get_value(entity: Variant, property: String) -> Variant: return entity.get(property)
func _validate_entity(entity: Variant) -> PackedStringArray: return entity.validate()
func _entity_label(entity: Variant) -> String:
	if entity == null: return ""
	if entity.get("name") != null and not str(entity.get("name")).is_empty(): return "%s (%s)" % [entity.get("name"), entity.id]
	if entity.get("display_name") != null and not str(entity.get("display_name")).is_empty(): return "%s (%s)" % [entity.get("display_name"), entity.id]
	if entity is Game: return "%s vs %s (%s)" % [entity.away_team_id, entity.home_team_id, entity.id]
	return entity.id

func _on_back_button_pressed() -> void:
	navigate_requested.emit(&"main_menu")
