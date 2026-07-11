extends Control

signal navigate_requested(screen_name: StringName)

const SaveManagerScript = preload("res://data/saving/save_manager.gd")
const SampleDataFactory = preload("res://data/sample_data_factory.gd")
const GameEventModel = preload("res://data/models/game_event.gd")
const PlayerModel = preload("res://data/models/player.gd")
const GameReplay = preload("res://data/game_replay.gd")

const EVENT_BUTTONS = [
	{"label": "1B", "event_type": "single", "legacy_type": "Single", "wired": true},
	{"label": "2B", "event_type": "double", "legacy_type": "Double", "wired": true},
	{"label": "3B", "event_type": "triple", "legacy_type": "Triple", "wired": true},
	{"label": "HR", "event_type": "home_run", "legacy_type": "Home run", "wired": true},
	{"label": "BB", "event_type": "walk", "legacy_type": "Walk", "wired": true},
	{"label": "HBP", "event_type": "hit_by_pitch", "legacy_type": "Hit by pitch", "wired": true},
	{"label": "K", "event_type": "strikeout", "legacy_type": "Strikeout", "wired": true},
	{"label": "GO", "event_type": "groundout", "legacy_type": "Groundout", "wired": true},
	{"label": "FO", "event_type": "flyout", "legacy_type": "Flyout", "wired": true},
	{"label": "E", "event_type": "reached_on_error", "legacy_type": "Reached on error", "wired": false},
	{"label": "FC", "event_type": "fielders_choice", "legacy_type": "Fielder's choice", "wired": false},
	{"label": "SAC", "event_type": "sacrifice", "legacy_type": "Sacrifice bunt", "wired": false},
	{"label": "SB", "event_type": "stolen_base", "legacy_type": "Stolen base", "wired": false},
	{"label": "CS", "event_type": "caught_stealing", "legacy_type": "Caught stealing", "wired": false},
	{"label": "Pitching Change", "event_type": "pitching_change", "legacy_type": "Pitching change", "wired": true},
	{"label": "Substitution", "event_type": "substitution", "legacy_type": "Substitution", "wired": false},
	{"label": "Manual", "event_type": "manual", "legacy_type": "Manual correction", "wired": false},
]
const EVENT_TYPES = ["Single", "Double", "Triple", "Home run", "Walk", "Hit by pitch", "Strikeout", "Groundout", "Flyout", "Reached on error", "Fielder's choice", "Sacrifice bunt", "Sacrifice fly", "Stolen base", "Caught stealing", "Pitching change", "Substitution", "Manual correction"]
const OUT_EVENTS = {"Strikeout": 1, "Groundout": 1, "Flyout": 1, "Sacrifice bunt": 1, "Sacrifice fly": 1, "Caught stealing": 1}

@onready var game_picker: OptionButton = %GamePicker
@onready var teams_label: Label = %TeamsLabel
@onready var away_lineup: TextEdit = %AwayLineup
@onready var home_lineup: TextEdit = %HomeLineup
@onready var add_player_team: OptionButton = %AddPlayerTeam
@onready var add_player_first_name: LineEdit = %AddPlayerFirstName
@onready var add_player_last_name: LineEdit = %AddPlayerLastName
@onready var add_player_jersey: LineEdit = %AddPlayerJersey
@onready var add_player_positions: LineEdit = %AddPlayerPositions
@onready var add_player_to_lineup: CheckBox = %AddPlayerToLineup
@onready var add_player_button: Button = %AddPlayerButton
@onready var add_player_status: Label = %AddPlayerStatus
@onready var away_pitcher: OptionButton = %AwayPitcher
@onready var home_pitcher: OptionButton = %HomePitcher
@onready var apply_setup_button: Button = %ApplySetupButton
@onready var score_label: Label = %ScoreLabel
@onready var inning_label: Label = %InningLabel
@onready var half_label: Label = %HalfLabel
@onready var outs_label: Label = %OutsLabel
@onready var count_label: Label = %CountLabel
@onready var bases_label: Label = %BasesLabel
@onready var event_type: OptionButton = %EventType
@onready var runs_spin: SpinBox = %RunsSpin
@onready var manual_outs_spin: SpinBox = %ManualOutsSpin
@onready var rbi_spin: SpinBox = %RbiSpin
@onready var batter_picker: OptionButton = %Batter
@onready var pitcher_picker: OptionButton = %Pitcher
@onready var notes: LineEdit = %Notes
@onready var manual_override_panel: ManualOverridePanel = %ManualOverridePanel
@onready var event_entry_panel: DynamicEventEntryPanel = %EventEntryPanel
@onready var event_buttons_grid: GridContainer = %EventButtonsGrid
@onready var lineup_list: ItemList = %LineupList
@onready var current_batter_label: Label = %CurrentBatterLabel
@onready var on_deck_label: Label = %OnDeckLabel
@onready var defense_label: Label = %DefenseLabel
@onready var current_pitcher_label: Label = %CurrentPitcherLabel
@onready var alignment_label: Label = %AlignmentLabel
@onready var defense_list: ItemList = %DefenseList
@onready var base_diamond: Label = %BaseDiamond
@onready var summary_preview_label: Label = %SummaryPreviewLabel
@onready var confirm_event_button: Button = %ConfirmEventButton
@onready var edit_event_button: Button = %EditEventButton
@onready var cancel_event_button: Button = %CancelEventButton
@onready var add_event_button: Button = %AddEventButton
@onready var undo_button: Button = %UndoButton
@onready var finalize_button: Button = %FinalizeButton
@onready var history: ItemList = %History
@onready var status_label: Label = %StatusLabel

var repository: DataRepository
var selected_game: Game
var current_inning = 1
var half_inning = "top"
var outs = 0
var score = {"away": 0, "home": 0}
var bases = {"1B": "", "2B": "", "3B": ""}
var lineups = {"away": [], "home": []}
var starting_pitchers = {"away": "", "home": ""}
var current_pitchers = {"away": "", "home": ""}
var pending_event_button: Dictionary = {}
var pending_payload: Dictionary = {}

func _ready() -> void:
	_load_repository()
	_connect_signals()
	_populate_static_options()
	_populate_games()
	_build_event_buttons()
	_select_game(0)

func _connect_signals() -> void:
	$Root/Header/BackButton.pressed.connect(func() -> void: navigate_requested.emit(&"main_menu"))
	game_picker.item_selected.connect(_select_game)
	apply_setup_button.pressed.connect(_apply_setup)
	add_player_button.pressed.connect(_add_player_to_current_game_team)
	add_event_button.pressed.connect(_add_event)
	undo_button.pressed.connect(_undo_last_event)
	finalize_button.pressed.connect(_finalize_game)
	confirm_event_button.pressed.connect(_confirm_pending_event)
	edit_event_button.pressed.connect(_refresh_pending_preview)
	cancel_event_button.pressed.connect(_cancel_pending_event)
	event_type.item_selected.connect(func(_i: int) -> void: _sync_default_outs())

func _load_repository() -> void:
	repository = SaveManagerScript.load_project()
	if repository == null:
		repository = SaveManagerScript.new_project()
		var sample = SampleDataFactory.create_sample_competition()
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


func _build_event_buttons() -> void:
	for child in event_buttons_grid.get_children():
		child.queue_free()
	for config in EVENT_BUTTONS:
		var button = Button.new()
		button.text = str(config["label"])
		button.tooltip_text = str(config["legacy_type"]) if bool(config["wired"]) else "%s not implemented yet" % str(config["legacy_type"])
		button.disabled = not bool(config["wired"])
		if bool(config["wired"]):
			button.pressed.connect(func(c = config) -> void: _open_event_template(c))
		event_buttons_grid.add_child(button)

func _open_event_template(config: Dictionary) -> void:
	pending_event_button = config.duplicate(true)
	event_type.select(_event_type_index(str(config["legacy_type"])))
	_sync_default_outs()
	event_entry_panel.open_for_event(str(config["event_type"]), _current_game_context())
	_refresh_pending_preview()
	confirm_event_button.disabled = false
	edit_event_button.disabled = false
	cancel_event_button.disabled = false

func _refresh_pending_preview() -> void:
	if pending_event_button.is_empty():
		return
	pending_payload = event_entry_panel.get_event_payload()
	pending_payload["result"] = pending_event_button.get("legacy_type", pending_payload.get("event_type", ""))
	pending_payload["runs_scored"] = int(runs_spin.value)
	pending_payload["rbi_count"] = int(rbi_spin.value)
	pending_payload["outs_after"] = outs + int(manual_outs_spin.value)
	pending_payload["batter_name"] = _player_or_text(str(pending_payload.get("batter_id", "")))
	pending_payload["pitcher_name"] = _player_or_text(str(pending_payload.get("pitcher_id", "")))
	var issues = event_entry_panel.validate()
	var summary = EventSummaryFormatter.summarize(pending_payload)
	if not issues.is_empty():
		summary += "\nNeeds review: " + "; ".join(issues)
	summary_preview_label.text = summary

func _cancel_pending_event() -> void:
	pending_event_button.clear()
	pending_payload.clear()
	event_entry_panel.reset()
	summary_preview_label.text = "Choose an event button to preview the entry."
	confirm_event_button.disabled = true
	edit_event_button.disabled = true
	cancel_event_button.disabled = true

func _confirm_pending_event() -> void:
	if pending_event_button.is_empty():
		return
	_refresh_pending_preview()
	_add_event_from_pending()

func _current_game_context() -> Dictionary:
	return {
		"game_id": selected_game.id if selected_game != null else "",
		"inning": current_inning,
		"half": half_inning,
		"outs": outs,
		"score": score.duplicate(true),
		"base_state": bases.duplicate(true),
		"offense_team_id": _offense_team_id() if selected_game != null else "",
		"defense_team_id": _defense_team_id() if selected_game != null else "",
		"batter_id": _selected_meta(batter_picker),
		"pitcher_id": _selected_meta(pitcher_picker),
		"outgoing_pitcher_id": _selected_meta(pitcher_picker),
		"offensive_lineup": _player_dicts_for_team(_offense_team_id()) if selected_game != null else [],
		"defensive_players": _player_dicts_for_team(_defense_team_id()) if selected_game != null else [],
	}

func _populate_games() -> void:
	game_picker.clear()
	for game in repository.games:
		game_picker.add_item(_game_label(game))
		game_picker.set_item_metadata(game_picker.item_count - 1, game.id)

func _select_game(index: int) -> void:
	if game_picker.item_count == 0:
		selected_game = null
		teams_label.text = "No games available. Create a game in Data Entry first."
		_refresh_add_player_team_options()
		return
	selected_game = repository.find_entity_by_id(str(game_picker.get_item_metadata(index)), "games")
	_build_setup_from_game()
	_refresh_add_player_team_options()
	_replay_events()
	_refresh_all()

func _build_setup_from_game() -> void:
	var away_players = _players_for_team(selected_game.away_team_id)
	var home_players = _players_for_team(selected_game.home_team_id)
	away_lineup.text = "\n".join(_player_labels(away_players))
	home_lineup.text = "\n".join(_player_labels(home_players))
	_fill_player_options(away_pitcher, away_players)
	_fill_player_options(home_pitcher, home_players)
	lineups["away"] = _text_lines(away_lineup.text)
	lineups["home"] = _text_lines(home_lineup.text)
	teams_label.text = "Away: %s\nHome: %s" % [_team_name(selected_game.away_team_id), _team_name(selected_game.home_team_id)]

func _refresh_add_player_team_options() -> void:
	add_player_team.clear()
	if selected_game == null:
		add_player_button.disabled = true
		return
	add_player_team.add_item("Away: %s" % _team_name(selected_game.away_team_id))
	add_player_team.set_item_metadata(add_player_team.item_count - 1, selected_game.away_team_id)
	add_player_team.add_item("Home: %s" % _team_name(selected_game.home_team_id))
	add_player_team.set_item_metadata(add_player_team.item_count - 1, selected_game.home_team_id)
	add_player_button.disabled = false

func _add_player_to_current_game_team() -> void:
	if selected_game == null:
		add_player_status.text = "Select a game first."
		return
	var team_id = _selected_meta(add_player_team)
	if not [selected_game.away_team_id, selected_game.home_team_id].has(team_id):
		add_player_status.text = "Choose the away or home team for this game."
		return
	var first_name = add_player_first_name.text.strip_edges()
	var last_name = add_player_last_name.text.strip_edges()
	if first_name.is_empty():
		add_player_status.text = "Player first name is required."
		return
	if last_name.is_empty():
		add_player_status.text = "Player last name is required."
		return
	var display_name = last_name
	var player = PlayerModel.new(_new_player_id(team_id, display_name), team_id, display_name)
	player.first_name = first_name
	player.last_name = last_name
	player.jersey_number = add_player_jersey.text.strip_edges()
	player.positions.assign(_csv_to_array(add_player_positions.text))
	var warnings = player.validate()
	if not warnings.is_empty():
		add_player_status.text = "\n".join(warnings)
		return
	if not repository.add_player(player):
		add_player_status.text = "Could not add player. Try again."
		return
	var err = SaveManagerScript.save_project(repository)
	if err != OK:
		add_player_status.text = "Player added, but save failed: %d" % err
		return
	_after_player_added(player)

func _after_player_added(player: Player) -> void:
	if add_player_to_lineup.button_pressed:
		var lineup_edit = away_lineup if player.team_id == selected_game.away_team_id else home_lineup
		var label = _player_label(player)
		var existing = _text_lines(lineup_edit.text)
		if not existing.has(label):
			lineup_edit.text = label if lineup_edit.text.strip_edges().is_empty() else "%s\n%s" % [lineup_edit.text, label]
	lineups["away"] = _text_lines(away_lineup.text)
	lineups["home"] = _text_lines(home_lineup.text)
	_fill_player_options(away_pitcher, _players_for_team(selected_game.away_team_id))
	_fill_player_options(home_pitcher, _players_for_team(selected_game.home_team_id))
	_refresh_matchup_options()
	_refresh_lineup_and_defense()
	add_player_first_name.text = ""
	add_player_last_name.text = ""
	add_player_jersey.text = ""
	add_player_positions.text = ""
	add_player_status.text = "Added %s to %s." % [_player_label(player), _team_name(player.team_id)]

func _apply_setup() -> void:
	lineups["away"] = _text_lines(away_lineup.text)
	lineups["home"] = _text_lines(home_lineup.text)
	starting_pitchers["away"] = _selected_meta(away_pitcher)
	starting_pitchers["home"] = _selected_meta(home_pitcher)
	selected_game.status = "In Progress"
	SaveManagerScript.save_project(repository)
	_refresh_matchup_options()
	_refresh_state_labels()
	_refresh_lineup_and_defense()
	status_label.text = "Setup confirmed. Away bats in the top half; home bats in the bottom half."

func _add_event() -> void:
	if selected_game == null:
		return
	pending_event_button = {"legacy_type": event_type.get_item_text(event_type.selected), "event_type": _normalize_event_type(event_type.get_item_text(event_type.selected)), "wired": true}
	pending_payload = {"details": {}}
	_add_event_from_pending()

func _add_event_from_pending() -> void:
	if selected_game == null:
		return
	var type = str(pending_event_button.get("legacy_type", event_type.get_item_text(event_type.selected)))
	var event = GameEventModel.new(_new_event_id(), selected_game.id)
	event.sequence_number = _game_events().size() + 1
	event.sequence = event.sequence_number
	event.inning = current_inning
	event.half = half_inning
	event.half_inning = half_inning
	event.offense_team_id = _offense_team_id()
	event.offensive_team_id = event.offense_team_id
	event.defense_team_id = _defense_team_id()
	event.defensive_team_id = event.defense_team_id
	event.batter_id = _selected_meta(batter_picker)
	event.pitcher_id = _selected_meta(pitcher_picker)
	event.event_type = type
	event.result = type
	event.base_state_before = bases.duplicate(true)
	event.score_before = score.duplicate(true)
	event.outs_before = outs
	event.outs_added = int(manual_outs_spin.value)
	event.outs_after = outs + event.outs_added
	event.runs_scored = int(runs_spin.value)
	event.rbi_count = int(rbi_spin.value)
	event.notes = notes.text.strip_edges()
	event.details = Dictionary(pending_payload.get("details", {})).duplicate(true)
	event.details["event_type"] = pending_event_button.get("event_type", _normalize_event_type(type))
	if event.details["event_type"] == "pitching_change":
		var pitching_change = Dictionary(event.details.get("pitching_change", {}))
		event.pitcher_id = str(pitching_change.get("incoming_pitcher_id", event.pitcher_id))
		event.batter_id = ""
		event.outs_added = 0
		event.outs_after = outs
		event.runs_scored = 0
		event.rbi_count = 0
	event.details["summary_preview"] = summary_preview_label.text
	if manual_override_panel.has_active_overrides():
		event.details["manual_overrides"] = manual_override_panel.get_overrides()
		event.manual_overrides = manual_override_panel.get_overrides()
	event.manual_override = type == "Manual correction" or event.runs_scored > 0 or not event.notes.is_empty() or manual_override_panel.has_active_overrides()
	repository.add_game_event(event)
	_replay_events(true)
	selected_game.status = "In Progress"
	SaveManagerScript.save_project(repository)
	notes.text = ""
	manual_override_panel.reset()
	_cancel_pending_event()
	_sync_default_outs()
	_refresh_all()

func _apply_replay_state(replay_state: GameReplayState) -> void:
	current_inning = replay_state.inning
	half_inning = replay_state.half_inning
	outs = replay_state.outs
	score = replay_state.score.duplicate(true)
	bases = replay_state.bases.duplicate(true)
	current_pitchers = replay_state.current_pitchers.duplicate(true)

func _undo_last_event() -> void:
	var events = _game_events()
	if events.is_empty(): return
	var event: GameEvent = events[-1]
	repository.game_events.erase(event)
	selected_game.event_ids.erase(event.id)
	_replay_events()
	SaveManagerScript.save_project(repository)
	_refresh_all()
	status_label.text = "Removed the most recent event and replayed game state."

func _replay_events(mutate_events: bool = false) -> void:
	_apply_replay_state(GameReplay.replay(_game_events(), starting_pitchers, mutate_events))

func _refresh_all() -> void:
	_refresh_matchup_options()
	_refresh_state_labels()
	_refresh_lineup_and_defense()
	_refresh_history()

func _refresh_matchup_options() -> void:
	var offensive_side = "away" if half_inning == "top" else "home"
	var offensive_team = selected_game.away_team_id if offensive_side == "away" else selected_game.home_team_id
	_fill_lineup_options(batter_picker, lineups[offensive_side], offensive_team)
	var defensive_team = selected_game.home_team_id if half_inning == "top" else selected_game.away_team_id
	_fill_player_options(pitcher_picker, _players_for_team(defensive_team))
	_select_option_by_meta(pitcher_picker, str(current_pitchers.get("home" if half_inning == "top" else "away", "")))

func _refresh_state_labels() -> void:
	score_label.text = "%s %d  —  %s %d" % [_team_name(selected_game.away_team_id), score["away"], _team_name(selected_game.home_team_id), score["home"]]
	inning_label.text = "Inning: %d" % current_inning
	half_label.text = "Half: %s" % half_inning.capitalize()
	outs_label.text = "Outs: %d" % outs
	count_label.text = "Count: use event panel"
	bases_label.text = "Bases: 1B=%s, 2B=%s, 3B=%s" % [_runner_name(bases["1B"]), _runner_name(bases["2B"]), _runner_name(bases["3B"])]
	base_diamond.text = "      2B: %s\n\n3B: %s          1B: %s\n\n      HP" % [_runner_name(bases["2B"]), _runner_name(bases["3B"]), _runner_name(bases["1B"])]

func _refresh_lineup_and_defense() -> void:
	lineup_list.clear()
	var offensive_side = "away" if half_inning == "top" else "home"
	for name in lineups[offensive_side]:
		lineup_list.add_item(str(name))
	var batter_text = batter_picker.get_item_text(batter_picker.selected) if batter_picker.selected >= 0 else "—"
	current_batter_label.text = "Current batter: %s" % batter_text
	var next_index = min(batter_picker.selected + 1, batter_picker.item_count - 1)
	on_deck_label.text = "On deck: %s" % (batter_picker.get_item_text(next_index) if next_index >= 0 and batter_picker.item_count > 1 else "—")
	defense_label.text = "Defensive team: %s" % _team_name(_defense_team_id())
	current_pitcher_label.text = "Current pitcher: %s" % (pitcher_picker.get_item_text(pitcher_picker.selected) if pitcher_picker.selected >= 0 else "—")
	defense_list.clear()
	for player in _players_for_team(_defense_team_id()):
		defense_list.add_item(_player_label(player))
	alignment_label.text = "Defensive alignment: available roster"

func _refresh_history() -> void:
	history.clear()
	for event in _game_events():
		history.add_item("#%d %s %d %s" % [event.sequence_number, event.half_inning.capitalize(), event.inning, _history_event_label(event)])

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
	var events = repository.game_events.filter(func(e: GameEvent) -> bool: return selected_game != null and e.game_id == selected_game.id)
	events.sort_custom(func(a: GameEvent, b: GameEvent) -> bool: return a.sequence_number < b.sequence_number)
	return events

func _history_event_label(event: GameEvent) -> String:
	if str(event.details.get("event_type", "")) == "pitching_change":
		var change = Dictionary(event.details.get("pitching_change", {}))
		return "Pitching change: %s replaces %s" % [_player_or_text(str(change.get("incoming_pitcher_id", event.pitcher_id))), _player_or_text(str(change.get("outgoing_pitcher_id", "")))]
	return "%s: %s, runs %d, outs %d" % [_player_or_text(event.batter_id), event.event_type, event.runs_scored, event.outs_added]

func _select_option_by_meta(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == value:
			option.select(index)
			return

func _fill_player_options(option: OptionButton, players: Array) -> void:
	option.clear()
	option.add_item("(none)"); option.set_item_metadata(0, "")
	for player in players:
		option.add_item(_player_label(player)); option.set_item_metadata(option.item_count - 1, player.id)

func _fill_lineup_options(option: OptionButton, names: Array, team_id: String) -> void:
	option.clear()
	for name in names:
		var label = str(name)
		option.add_item(label)
		option.set_item_metadata(option.item_count - 1, _player_id_for_label(label, team_id))
	if option.item_count == 0:
		option.add_item("Manual batter")
		option.set_item_metadata(0, "")

func _players_for_team(team_id: String) -> Array:
	return repository.players.filter(func(p: Player) -> bool: return p.team_id == team_id)

func _player_labels(players: Array) -> PackedStringArray:
	var labels = PackedStringArray()
	for player in players:
		labels.append(_player_label(player))
	return labels

func _player_id_for_label(label: String, team_id: String) -> String:
	for player in _players_for_team(team_id):
		if _player_label(player) == label or player.display_name == label:
			return player.id
	return label

func _text_lines(text: String) -> Array:
	var output = []
	for line in text.split("\n"):
		var trimmed = line.strip_edges()
		if not trimmed.is_empty(): output.append(trimmed)
	return output

func _csv_to_array(value: String) -> Array[String]:
	var output: Array[String] = []
	for item in value.split(","):
		var trimmed = item.strip_edges()
		if not trimmed.is_empty(): output.append(trimmed)
	return output

func _selected_meta(option: OptionButton) -> String:
	return str(option.get_item_metadata(option.selected)) if option.selected >= 0 else ""

func _offense_team_id() -> String: return selected_game.away_team_id if half_inning == "top" else selected_game.home_team_id
func _defense_team_id() -> String: return selected_game.home_team_id if half_inning == "top" else selected_game.away_team_id
func _new_event_id() -> String: return "%s_event_%d" % [selected_game.id, int(Time.get_unix_time_from_system() * 1000) + _game_events().size()]
func _new_player_id(team_id: String, display_name: String) -> String:
	var team: Team = repository.find_entity_by_id(team_id, "teams")
	var region = team.region.strip_edges() if team != null else team_id
	var abbreviation = team.abbreviation.strip_edges() if team != null else team_id
	var base_id = "%s_%s_%s" % [region, abbreviation, display_name.strip_edges()]
	var candidate = base_id
	var suffix = 1
	while repository.find_entity_by_id(candidate, "players") != null:
		suffix += 1
		candidate = "%s_%d" % [base_id, suffix]
	return candidate

func _game_label(game: Game) -> String: return "%s at %s — %s" % [_team_name(game.away_team_id), _team_name(game.home_team_id), game.date]
func _team_name(team_id: String) -> String:
	var team: Team = repository.find_entity_by_id(team_id, "teams")
	return team.name if team != null else team_id
func _player_label(player: Player) -> String: return "#%s %s" % [player.jersey_number, player.display_name]
func _runner_name(value: String) -> String: return "empty" if value.is_empty() else _player_or_text(value)
func _player_or_text(value: String) -> String:
	var player: Player = repository.find_entity_by_id(value, "players")
	return _player_label(player) if player != null else value


func _player_dicts_for_team(team_id: String) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for player in _players_for_team(team_id):
		output.append({"id": player.id, "player_id": player.id, "display_name": _player_label(player), "name": _player_label(player)})
	return output

func _event_type_index(type: String) -> int:
	for index in range(event_type.item_count):
		if event_type.get_item_text(index) == type:
			return index
	return 0

func _normalize_event_type(type: String) -> String:
	return type.strip_edges().to_lower().replace(" ", "_").replace("-", "_").replace("'", "")
