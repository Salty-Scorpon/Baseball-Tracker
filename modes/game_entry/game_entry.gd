extends Control

signal navigate_requested(screen_name: StringName)

const SaveManagerScript := preload("res://data/saving/save_manager.gd")
const SampleDataFactory := preload("res://data/sample_data_factory.gd")
const GameEventModel := preload("res://data/models/game_event.gd")

const EVENT_TYPES := ["Single", "Double", "Triple", "Home run", "Walk", "Hit by pitch", "Strikeout", "Groundout", "Flyout", "Reached on error", "Fielder's choice", "Sacrifice bunt", "Sacrifice fly", "Stolen base", "Caught stealing", "Pitching change", "Substitution", "Manual correction"]
const OUT_EVENTS := {"Strikeout": 1, "Groundout": 1, "Flyout": 1, "Sacrifice bunt": 1, "Sacrifice fly": 1, "Caught stealing": 1}
const ADVANCE_EVENTS := {"Single": 1, "Double": 2, "Triple": 3, "Home run": 4, "Walk": 1, "Hit by pitch": 1, "Reached on error": 1, "Fielder's choice": 1}

@onready var game_picker: OptionButton = %GamePicker
@onready var teams_label: Label = %TeamsLabel
@onready var away_lineup: TextEdit = %AwayLineup
@onready var home_lineup: TextEdit = %HomeLineup
@onready var away_pitcher: OptionButton = %AwayPitcher
@onready var home_pitcher: OptionButton = %HomePitcher
@onready var apply_setup_button: Button = %ApplySetupButton
@onready var state_label: Label = %StateLabel
@onready var bases_label: Label = %BasesLabel
@onready var event_type: OptionButton = %EventType
@onready var runs_spin: SpinBox = %RunsSpin
@onready var manual_outs_spin: SpinBox = %ManualOutsSpin
@onready var rbi_spin: SpinBox = %RbiSpin
@onready var batter_picker: OptionButton = %Batter
@onready var pitcher_picker: OptionButton = %Pitcher
@onready var notes: LineEdit = %Notes
@onready var add_event_button: Button = %AddEventButton
@onready var undo_button: Button = %UndoButton
@onready var finalize_button: Button = %FinalizeButton
@onready var history: ItemList = %History
@onready var status_label: Label = %StatusLabel

var repository: DataRepository
var selected_game: Game
var current_inning := 1
var half_inning := "top"
var outs := 0
var score := {"away": 0, "home": 0}
var bases := {"1B": "", "2B": "", "3B": ""}
var lineups := {"away": [], "home": []}
var starting_pitchers := {"away": "", "home": ""}

func _ready() -> void:
	_load_repository()
	_connect_signals()
	_populate_static_options()
	_populate_games()
	_select_game(0)

func _connect_signals() -> void:
	$Root/Header/BackButton.pressed.connect(func() -> void: navigate_requested.emit(&"main_menu"))
	game_picker.item_selected.connect(_select_game)
	apply_setup_button.pressed.connect(_apply_setup)
	add_event_button.pressed.connect(_add_event)
	undo_button.pressed.connect(_undo_last_event)
	finalize_button.pressed.connect(_finalize_game)
	event_type.item_selected.connect(func(_i: int) -> void: _sync_default_outs())

func _load_repository() -> void:
	repository = SaveManagerScript.load_project()
	if repository == null:
		repository = SaveManagerScript.new_project()
		var sample := SampleDataFactory.create_sample_competition()
		repository.add_ruleset(sample["rulesets"][0])
		repository.add_competition(sample["competition"])
		for team in sample["teams"]: repository.add_team(team)
		for player in sample["players"]: repository.add_player(player)
		for game in sample["games"]: repository.add_game(game)
		SaveManagerScript.save_project(repository)
		status_label.text = "Started with sample data. Edit teams/games in Data Entry when ready."

func _populate_static_options() -> void:
	for type in EVENT_TYPES:
		event_type.add_item(type)
	_sync_default_outs()

func _populate_games() -> void:
	game_picker.clear()
	for game in repository.games:
		game_picker.add_item(_game_label(game))
		game_picker.set_item_metadata(game_picker.item_count - 1, game.id)

func _select_game(index: int) -> void:
	if game_picker.item_count == 0:
		selected_game = null
		teams_label.text = "No games available. Create a game in Data Entry first."
		return
	selected_game = repository.find_entity_by_id(str(game_picker.get_item_metadata(index)), "games")
	_build_setup_from_game()
	_replay_events()
	_refresh_all()

func _build_setup_from_game() -> void:
	var away_players := _players_for_team(selected_game.away_team_id)
	var home_players := _players_for_team(selected_game.home_team_id)
	away_lineup.text = "\n".join(_player_labels(away_players))
	home_lineup.text = "\n".join(_player_labels(home_players))
	_fill_player_options(away_pitcher, away_players)
	_fill_player_options(home_pitcher, home_players)
	lineups["away"] = _text_lines(away_lineup.text)
	lineups["home"] = _text_lines(home_lineup.text)
	teams_label.text = "Away: %s\nHome: %s" % [_team_name(selected_game.away_team_id), _team_name(selected_game.home_team_id)]

func _apply_setup() -> void:
	lineups["away"] = _text_lines(away_lineup.text)
	lineups["home"] = _text_lines(home_lineup.text)
	starting_pitchers["away"] = _selected_meta(away_pitcher)
	starting_pitchers["home"] = _selected_meta(home_pitcher)
	selected_game.status = "In Progress"
	SaveManagerScript.save_project(repository)
	_refresh_matchup_options()
	_refresh_state_labels()
	status_label.text = "Setup confirmed. Away bats in the top half; home bats in the bottom half."

func _add_event() -> void:
	if selected_game == null: return
	var type := event_type.get_item_text(event_type.selected)
	var event := GameEventModel.new(_new_event_id(), selected_game.id)
	event.sequence_number = _game_events().size() + 1
	event.inning = current_inning
	event.half_inning = half_inning
	event.offensive_team_id = _offense_team_id()
	event.defensive_team_id = _defense_team_id()
	event.batter_id = _selected_meta(batter_picker)
	event.pitcher_id = _selected_meta(pitcher_picker)
	event.event_type = type
	event.result = type
	event.base_state_before = bases.duplicate(true)
	event.outs_added = int(manual_outs_spin.value)
	event.runs_scored = int(runs_spin.value)
	event.rbi_count = int(rbi_spin.value)
	event.notes = notes.text.strip_edges()
	event.manual_override = type == "Manual correction" or event.runs_scored > 0 or not event.notes.is_empty()
	_apply_event_to_state(event)
	event.base_state_after = bases.duplicate(true)
	repository.add_game_event(event)
	selected_game.status = "In Progress"
	SaveManagerScript.save_project(repository)
	notes.text = ""
	_sync_default_outs()
	_refresh_all()

func _apply_event_to_state(event: GameEvent) -> void:
	if ADVANCE_EVENTS.has(event.event_type):
		_advance_runners(int(ADVANCE_EVENTS[event.event_type]), event.batter_id, event.event_type == "Home run")
	elif event.event_type == "Stolen base":
		_steal_one_base()
	outs += event.outs_added
	_add_runs(event.runs_scored)
	while outs >= 3:
		outs -= 3
		bases = {"1B": "", "2B": "", "3B": ""}
		if half_inning == "top":
			half_inning = "bottom"
		else:
			half_inning = "top"
			current_inning += 1

func _advance_runners(bases_to_advance: int, batter_id: String, clear_bases: bool = false) -> void:
	var occupied := [bases["3B"], bases["2B"], bases["1B"]]
	bases = {"1B": "", "2B": "", "3B": ""}
	for runner in occupied:
		if runner.is_empty(): continue
		var from_base := 3 - occupied.find(runner)
		var target := from_base + bases_to_advance
		if target <= 3: bases["%dB" % target] = runner
	if not batter_id.is_empty() and not clear_bases and bases_to_advance <= 3:
		bases["%dB" % bases_to_advance] = batter_id

func _steal_one_base() -> void:
	if not bases["2B"].is_empty() and bases["3B"].is_empty(): bases["3B"] = bases["2B"]; bases["2B"] = ""
	elif not bases["1B"].is_empty() and bases["2B"].is_empty(): bases["2B"] = bases["1B"]; bases["1B"] = ""

func _add_runs(count: int) -> void:
	if half_inning == "top": score["away"] += count
	else: score["home"] += count

func _undo_last_event() -> void:
	var events := _game_events()
	if events.is_empty(): return
	var event: GameEvent = events[-1]
	repository.game_events.erase(event)
	selected_game.event_ids.erase(event.id)
	_replay_events()
	SaveManagerScript.save_project(repository)
	_refresh_all()
	status_label.text = "Removed the most recent event and replayed game state."

func _replay_events() -> void:
	current_inning = 1; half_inning = "top"; outs = 0; score = {"away": 0, "home": 0}; bases = {"1B": "", "2B": "", "3B": ""}
	for event in _game_events():
		_apply_event_to_state(event)

func _refresh_all() -> void:
	_refresh_matchup_options()
	_refresh_state_labels()
	_refresh_history()

func _refresh_matchup_options() -> void:
	_fill_lineup_options(batter_picker, lineups["away"] if half_inning == "top" else lineups["home"])
	var defensive_team := selected_game.home_team_id if half_inning == "top" else selected_game.away_team_id
	_fill_player_options(pitcher_picker, _players_for_team(defensive_team))

func _refresh_state_labels() -> void:
	state_label.text = "%s %d | Outs: %d | Score %s %d - %s %d" % [half_inning.capitalize(), current_inning, outs, _team_name(selected_game.away_team_id), score["away"], _team_name(selected_game.home_team_id), score["home"]]
	bases_label.text = "Bases: 1B=%s, 2B=%s, 3B=%s" % [_runner_name(bases["1B"]), _runner_name(bases["2B"]), _runner_name(bases["3B"])]

func _refresh_history() -> void:
	history.clear()
	for event in _game_events():
		history.add_item("#%d %s %d %s: %s, runs %d, outs %d" % [event.sequence_number, event.half_inning.capitalize(), event.inning, _player_or_text(event.batter_id), event.event_type, event.runs_scored, event.outs_added])

func _finalize_game() -> void:
	if selected_game == null: return
	selected_game.status = "Final"
	SaveManagerScript.save_project(repository)
	status_label.text = "Final score saved: %s %d - %s %d" % [_team_name(selected_game.away_team_id), score["away"], _team_name(selected_game.home_team_id), score["home"]]

func _sync_default_outs() -> void:
	if event_type.item_count == 0: return
	manual_outs_spin.value = OUT_EVENTS.get(event_type.get_item_text(event_type.selected), 0)
	runs_spin.value = 0
	rbi_spin.value = 0

func _game_events() -> Array:
	var events := repository.game_events.filter(func(e: GameEvent) -> bool: return selected_game != null and e.game_id == selected_game.id)
	events.sort_custom(func(a: GameEvent, b: GameEvent) -> bool: return a.sequence_number < b.sequence_number)
	return events

func _fill_player_options(option: OptionButton, players: Array) -> void:
	option.clear()
	option.add_item("(none)"); option.set_item_metadata(0, "")
	for player in players:
		option.add_item(_player_label(player)); option.set_item_metadata(option.item_count - 1, player.id)

func _fill_lineup_options(option: OptionButton, names: Array) -> void:
	option.clear()
	for name in names:
		option.add_item(str(name)); option.set_item_metadata(option.item_count - 1, str(name))
	if option.item_count == 0:
		option.add_item("Manual batter"); option.set_item_metadata(0, "")

func _players_for_team(team_id: String) -> Array:
	return repository.players.filter(func(p: Player) -> bool: return p.team_id == team_id)

func _player_labels(players: Array) -> PackedStringArray:
	var labels := PackedStringArray()
	for player in players:
		labels.append(_player_label(player))
	return labels

func _text_lines(text: String) -> Array:
	var output := []
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if not trimmed.is_empty(): output.append(trimmed)
	return output

func _selected_meta(option: OptionButton) -> String:
	return str(option.get_item_metadata(option.selected)) if option.selected >= 0 else ""

func _offense_team_id() -> String: return selected_game.away_team_id if half_inning == "top" else selected_game.home_team_id
func _defense_team_id() -> String: return selected_game.home_team_id if half_inning == "top" else selected_game.away_team_id
func _new_event_id() -> String: return "%s_event_%d" % [selected_game.id, int(Time.get_unix_time_from_system() * 1000) + _game_events().size()]
func _game_label(game: Game) -> String: return "%s at %s — %s" % [_team_name(game.away_team_id), _team_name(game.home_team_id), game.date]
func _team_name(team_id: String) -> String:
	var team: Team = repository.find_entity_by_id(team_id, "teams")
	return team.name if team != null else team_id
func _player_label(player: Player) -> String: return "#%s %s" % [player.jersey_number, player.display_name]
func _runner_name(value: String) -> String: return "empty" if value.is_empty() else _player_or_text(value)
func _player_or_text(value: String) -> String:
	var player: Player = repository.find_entity_by_id(value, "players")
	return _player_label(player) if player != null else value
