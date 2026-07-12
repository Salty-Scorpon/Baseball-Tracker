extends Control

signal navigate_requested(screen_name: StringName)
signal event_key_selected(event_type: String)
signal add_player_requested(team_id: String)

const GameEntryStyle = preload("res://modes/game_entry/GameEntryStyle.gd")
const SaveManagerScript = preload("res://data/saving/save_manager.gd")
const SampleDataFactoryScript = preload("res://data/sample_data_factory.gd")
const EventSummaryFormatterScript = preload("res://app/EventSummaryFormatter.gd")
const EventValidatorScript = preload("res://app/EventValidator.gd")
const GameStateSnapshotScript = preload("res://data/game_state_snapshot.gd")
const GameEventScript = preload("res://data/models/game_event.gd")

@onready var background: ColorRect = %Background
@onready var left_dock: PanelContainer = %LeftDock
@onready var center_dock: PanelContainer = %CenterDock
@onready var right_dock: PanelContainer = %RightDock
@onready var event_key_panel: EventKeyPanel = %EventKeyPanel
@onready var team_quick_roster_panel: TeamQuickRosterPanel = %TeamQuickRosterPanel
@onready var add_player_button: Button = %AddPlayerButton
@onready var workspace_panel: WorkspacePanel = %WorkspacePanel
@onready var event_summary_panel: EventSummaryPanel = %EventSummaryPanel
@onready var skinny_event_history_panel: SkinnyEventHistoryPanel = %SkinnyEventHistoryPanel
@onready var compact_scoreboard_panel: CompactScoreboardPanel = %CompactScoreboardPanel
@onready var workspace_label: Label = %WorkspaceTitleLabel
@onready var event_history_label: Label = %EventHistoryLabel
@onready var workspace_placeholder: Label = %WorkspaceContextLabel

var repository: DataRepository
var current_game: Game
var add_player_dialog: AcceptDialog
var jersey_number_field: LineEdit
var display_name_field: LineEdit
var position_field: LineEdit
var bats_field: LineEdit
var throws_field: LineEdit
var notes_field: TextEdit
var validation_label: Label
var duplicate_warning_label: Label
var _pending_add_team_id := ""
var _selected_event_id := ""
var _current_payload: Dictionary = {}
var _current_validation_messages: Array = []
var _editing_event_id := ""

func _ready() -> void:
	_apply_style()
	_build_add_player_dialog()
	event_key_panel.event_type_selected.connect(_on_event_key_pressed)
	workspace_panel.event_payload_changed.connect(_on_workspace_event_payload_changed)
	workspace_panel.event_selected.connect(_on_workspace_event_selected)
	workspace_panel.event_edit_requested.connect(_on_workspace_event_edit_requested)
	workspace_panel.event_creation_cancel_requested.connect(_on_workspace_event_creation_cancel_requested)
	event_summary_panel.confirm_requested.connect(_on_event_summary_confirm_requested)
	event_summary_panel.cancel_requested.connect(_on_event_summary_cancel_requested)
	event_summary_panel.edit_requested.connect(_on_event_summary_edit_requested)
	skinny_event_history_panel.event_selected.connect(_on_skinny_event_history_selected)
	team_quick_roster_panel.roster_team_tab_changed.connect(_on_roster_team_tab_changed)
	team_quick_roster_panel.player_selected.connect(_on_roster_player_selected)
	team_quick_roster_panel.add_player_requested.connect(_on_roster_add_player_requested)
	add_player_button.pressed.connect(team_quick_roster_panel.request_add_player)
	_load_repository()
	_refresh_game_context()

func _apply_style() -> void:
	GameEntryStyle.apply_shell_style(
		self,
		background,
		[left_dock, center_dock, right_dock],
		[event_key_panel, team_quick_roster_panel, workspace_panel, skinny_event_history_panel, compact_scoreboard_panel],
		[workspace_label, event_history_label],
		[workspace_placeholder],
		[add_player_button]
	)

func _load_repository() -> void:
	repository = SaveManagerScript.load_project()
	if repository == null:
		repository = SaveManagerScript.new_project()
		var sample := SampleDataFactoryScript.create_sample_competition()
		repository.add_competition(sample["competition"])
		for ruleset in sample["rulesets"]:
			repository.add_ruleset(ruleset)
		for team in sample["teams"]:
			repository.add_team(team)
		for player in sample["players"]:
			repository.add_player(player)
		for game in sample["games"]:
			repository.add_game(game)
	current_game = repository.games[0] if not repository.games.is_empty() else null

func _refresh_game_context() -> void:
	if current_game == null:
		team_quick_roster_panel.set_team_ids("", "")
		team_quick_roster_panel.set_home_roster([])
		team_quick_roster_panel.set_away_roster([])
		_update_add_player_button_state()
		skinny_event_history_panel.clear()
		compact_scoreboard_panel.clear()
		event_summary_panel.set_idle()
		return
	team_quick_roster_panel.set_team_ids(current_game.home_team_id, current_game.away_team_id)
	team_quick_roster_panel.set_home_roster(_players_for_team(current_game.home_team_id))
	team_quick_roster_panel.set_away_roster(_players_for_team(current_game.away_team_id))
	_update_add_player_button_state()
	var home_team: Team = repository.find_entity_by_id(current_game.home_team_id, "teams")
	var away_team: Team = repository.find_entity_by_id(current_game.away_team_id, "teams")
	var events := _events_for_current_game()
	var event_context := _event_log_context()
	workspace_panel.set_events(events, event_context)
	skinny_event_history_panel.set_events(events, event_context)
	compact_scoreboard_panel.set_state(_scoreboard_state_for_events(events))
	event_summary_panel.set_idle()

func _players_for_team(team_id: String) -> Array:
	var output: Array = []
	for player in repository.players:
		if player.team_id == team_id:
			output.append(player)
	return output

func _events_for_current_game() -> Array:
	var output: Array = []
	if repository == null or current_game == null:
		return output
	for event in repository.game_events:
		if event.game_id == current_game.id or current_game.event_ids.has(event.id):
			output.append(event)
	output.sort_custom(func(a: GameEvent, b: GameEvent) -> bool: return a.sequence < b.sequence)
	return output

func _event_log_context() -> Dictionary:
	var players_by_id := {}
	if repository != null:
		for player in repository.players:
			players_by_id[player.id] = player
	return {"players_by_id": players_by_id}

func _on_event_key_pressed(event_type: String) -> void:
	_editing_event_id = ""
	_current_payload.clear()
	_current_validation_messages.clear()
	workspace_panel.show_create_event_mode(event_type, _build_workspace_game_context())
	event_summary_panel.set_preview_text("Drafting event payload for: %s." % event_type.replace("_", " ").capitalize())
	event_summary_panel.set_validation_messages([{ "severity": "info", "message": "Complete the event form, then review validation before confirming." }])
	event_summary_panel.set_active(false)
	event_key_selected.emit(event_type)

func _on_workspace_event_payload_changed(payload: Dictionary) -> void:
	_current_payload = payload.duplicate(true)
	var preview := EventSummaryFormatterScript.summarize(_current_payload)
	_current_validation_messages = EventValidatorScript.validate_event_payload(_current_payload)
	event_summary_panel.set_preview_text(preview)
	event_summary_panel.set_validation_messages(_current_validation_messages)
	event_summary_panel.set_active(not EventValidatorScript.has_errors(_current_validation_messages))

func _on_skinny_event_history_selected(event_id: String) -> void:
	_selected_event_id = event_id
	workspace_panel.show_review_mode()
	workspace_panel.scroll_to_event(event_id)
	event_summary_panel.set_selected_event_summary(_summary_for_event(event_id))
	compact_scoreboard_panel.set_state(_scoreboard_state_for_event(event_id))

func _on_workspace_event_selected(event_id: String) -> void:
	_selected_event_id = event_id
	skinny_event_history_panel.select_event(event_id)
	event_summary_panel.set_selected_event_summary(_summary_for_event(event_id))
	compact_scoreboard_panel.set_state(_scoreboard_state_for_event(event_id))

func _on_workspace_event_edit_requested(event_id: String) -> void:
	if _is_current_game_finalized():
		event_summary_panel.set_validation_messages([{ "severity": "warning", "message": "This game is marked Final; editing is locked until a formal unlock workflow is added. TODO: add finalized-game unlock/override flow." }])
		return
	var event := _find_current_game_event(event_id)
	if event == null:
		event_summary_panel.set_validation_messages([{ "severity": "error", "message": "Could not find event %s in the current game log." % event_id }])
		return
	_selected_event_id = event_id
	_editing_event_id = event_id
	_current_payload = _payload_from_game_event(event)
	_current_validation_messages = EventValidatorScript.validate_event_payload(_current_payload)
	workspace_panel.show_edit_event_mode(event_id, _current_payload, _build_workspace_game_context_for_event(event))
	skinny_event_history_panel.select_event_silent(event_id)
	event_summary_panel.set_preview_text(EventSummaryFormatterScript.summarize(_current_payload))
	event_summary_panel.set_validation_messages(_current_validation_messages)
	event_summary_panel.set_active(not EventValidatorScript.has_errors(_current_validation_messages))

func _on_workspace_event_creation_cancel_requested() -> void:
	_editing_event_id = ""
	_current_payload.clear()
	_current_validation_messages.clear()
	event_summary_panel.set_idle()

func _summary_for_event(event_id: String) -> String:
	for event in _events_for_current_game():
		if event.id == event_id:
			return EventSummaryFormatterScript.summarize(event)
	return "Selected event %s. Event details will appear here when the saved event can be found." % event_id

func _on_event_summary_confirm_requested() -> void:
	if current_game == null:
		event_summary_panel.set_validation_messages([{ "severity": "error", "message": "No current game is available." }])
		return
	if _current_payload.is_empty():
		_current_payload = workspace_panel.get_event_payload()
	_current_validation_messages = EventValidatorScript.validate_event_payload(_current_payload)
	if EventValidatorScript.has_errors(_current_validation_messages):
		event_summary_panel.set_validation_messages(_current_validation_messages)
		event_summary_panel.set_active(false)
		return
	var existing_event := _find_current_game_event(_editing_event_id) if not _editing_event_id.is_empty() else null
	var event := _game_event_from_payload(_current_payload, existing_event)
	var saved := repository.update_game_event(event) if existing_event != null else repository.append_game_event(event)
	if not saved:
		var action := "update" if existing_event != null else "append"
		event_summary_panel.set_validation_messages([{ "severity": "error", "message": "Could not %s the event in the current game log." % action }])
		return
	SaveManagerScript.save_project(repository)
	_selected_event_id = event.id
	_editing_event_id = ""
	_current_payload.clear()
	_current_validation_messages.clear()
	_refresh_game_context()
	workspace_panel.show_review_mode()
	workspace_panel.scroll_to_event(event.id)
	skinny_event_history_panel.select_event(event.id)
	event_summary_panel.set_selected_event_summary(_summary_for_event(event.id))
	compact_scoreboard_panel.set_state(_scoreboard_state_for_event(event.id))

func _on_event_summary_cancel_requested() -> void:
	_editing_event_id = ""
	_current_payload.clear()
	_current_validation_messages.clear()
	workspace_panel.show_review_mode()
	if _selected_event_id.is_empty():
		event_summary_panel.set_idle()
	else:
		event_summary_panel.set_selected_event_summary(_summary_for_event(_selected_event_id))

func _on_event_summary_edit_requested() -> void:
	var event_id := _selected_event_id
	if event_id.is_empty():
		event_summary_panel.set_validation_messages([{ "severity": "info", "message": "Edit requested. Select a saved event from the narrative log to edit it." }])
	else:
		_on_workspace_event_edit_requested(event_id)

func _find_current_game_event(event_id: String) -> GameEvent:
	if event_id.is_empty():
		return null
	for event in _events_for_current_game():
		if event.id == event_id:
			return event
	return null

func _is_current_game_finalized() -> bool:
	return current_game != null and current_game.status.strip_edges().to_lower() == "final"

func _payload_from_game_event(event: GameEvent) -> Dictionary:
	var payload := event.to_dict()
	payload["event_id"] = event.id
	payload["mode"] = "editing_event"
	return payload

func _build_workspace_game_context_for_event(event: GameEvent) -> Dictionary:
	var context := _build_workspace_game_context()
	context["inning"] = event.inning
	context["half"] = event.half
	context["half_inning"] = event.half_inning
	context["outs"] = event.outs_before
	context["base_state"] = event.base_state_before.duplicate(true)
	context["score"] = event.score_before.duplicate(true)
	context["offense_team_id"] = event.offense_team_id
	context["defense_team_id"] = event.defense_team_id
	context["batter_id"] = event.batter_id
	context["pitcher_id"] = event.pitcher_id
	context["offensive_lineup"] = _players_for_team(event.offense_team_id)
	context["defensive_players"] = _players_for_team(event.defense_team_id)
	return context

func _build_workspace_game_context() -> Dictionary:
	if current_game == null:
		return {}
	var events := _events_for_current_game()
	var state := _scoreboard_state_for_events(events)
	var half := str(state.get("half", "Top"))
	var offense_team_id := current_game.away_team_id if half.to_lower() == "top" else current_game.home_team_id
	var defense_team_id := current_game.home_team_id if half.to_lower() == "top" else current_game.away_team_id
	return {
		"game_id": current_game.id,
		"inning": int(state.get("inning", 1)),
		"half": half,
		"half_inning": half,
		"outs": int(state.get("outs", 0)),
		"base_state": state.get("base_state", {}),
		"score": {"away": int(state.get("away_score", 0)), "home": int(state.get("home_score", 0))},
		"home_team_id": current_game.home_team_id,
		"away_team_id": current_game.away_team_id,
		"offense_team_id": offense_team_id,
		"defense_team_id": defense_team_id,
		"batter_id": _first_player_id_for_team(offense_team_id),
		"pitcher_id": _first_player_id_for_team(defense_team_id),
		"offensive_lineup": _players_for_team(offense_team_id),
		"defensive_players": _players_for_team(defense_team_id),
	}

func _game_event_from_payload(payload: Dictionary, existing_event: GameEvent = null) -> GameEvent:
	var events := _events_for_current_game()
	var next_sequence := events.size() + 1
	for existing in events:
		next_sequence = max(next_sequence, existing.sequence_number + 1)
	var event_id := existing_event.id if existing_event != null else _next_game_event_id()
	var event := GameEventScript.new(event_id, current_game.id)
	var event_type := _normalize_event_type(str(payload.get("event_type", "manual_correction")))
	var details := Dictionary(payload.get("details", {})).duplicate(true) if payload.get("details", {}) is Dictionary else {}
	details["event_type"] = event_type
	event.sequence = existing_event.sequence if existing_event != null else next_sequence
	event.sequence_number = existing_event.sequence_number if existing_event != null else next_sequence
	event.inning = int(payload.get("inning", 1))
	event.half = str(payload.get("half", payload.get("half_inning", "top"))).to_lower()
	event.half_inning = event.half
	event.event_type = event_type
	event.event_group = str(details.get("template", {}).get("event_group", "")) if details.get("template", {}) is Dictionary else ""
	event.batter_id = str(payload.get("batter_id", ""))
	event.pitcher_id = str(payload.get("pitcher_id", ""))
	event.offense_team_id = str(payload.get("offense_team_id", ""))
	event.offensive_team_id = event.offense_team_id
	event.defense_team_id = str(payload.get("defense_team_id", ""))
	event.defensive_team_id = event.defense_team_id
	event.outs_before = int(payload.get("outs_before", 0))
	event.outs_added = _placeholder_outs_added(event_type, details)
	var requested_outs_after := int(payload.get("outs_after", event.outs_before + event.outs_added))
	if payload.has("outs_after") and requested_outs_after > event.outs_before:
		event.outs_after = requested_outs_after
		event.outs_added = max(0, event.outs_after - event.outs_before)
	else:
		event.outs_after = event.outs_before + event.outs_added
	event.base_state_before = Dictionary(payload.get("base_state_before", {})).duplicate(true) if payload.get("base_state_before", {}) is Dictionary else {}
	event.base_state_after = Dictionary(payload.get("base_state_after", event.base_state_before)).duplicate(true) if payload.get("base_state_after", event.base_state_before) is Dictionary else event.base_state_before.duplicate(true)
	event.score_before = Dictionary(payload.get("score_before", {})).duplicate(true) if payload.get("score_before", {}) is Dictionary else {}
	event.score_after = Dictionary(payload.get("score_after", event.score_before)).duplicate(true) if payload.get("score_after", event.score_before) is Dictionary else event.score_before.duplicate(true)
	event.runs_scored = _payload_runs_scored(payload, event_type, details)
	event.rbi_count = event.runs_scored
	event.details = details
	event.manual_overrides = Dictionary(details.get("manual_overrides", payload.get("manual_overrides", {}))).duplicate(true) if details.get("manual_overrides", payload.get("manual_overrides", {})) is Dictionary else {}
	event.manual_override = not event.manual_overrides.is_empty()
	event.notes = str(payload.get("notes", details.get("notes", ""))).strip_edges()
	event.result = _legacy_event_label(event_type)
	return event

func _next_game_event_id() -> String:
	var index := repository.game_events.size() + 1 if repository != null else 1
	while repository != null and repository.find_entity_by_id("event_%03d" % index, "game_events") != null:
		index += 1
	return "event_%03d" % index

func _normalize_event_type(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")

func _legacy_event_label(event_type: String) -> String:
	var labels := {"single":"Single", "double":"Double", "triple":"Triple", "home_run":"Home run", "walk":"Walk", "hit_by_pitch":"Hit by pitch", "reached_on_error":"Reached on error", "fielders_choice":"Fielder's choice", "stolen_base":"Stolen base"}
	return str(labels.get(event_type, event_type.replace("_", " ").capitalize()))

func _placeholder_outs_added(event_type: String, details: Dictionary) -> int:
	if details.has("out_assignments") and details["out_assignments"] is Array:
		return min(3, details["out_assignments"].size())
	if ["strikeout", "groundout", "flyout", "sacrifice_bunt", "sacrifice_fly", "caught_stealing"].has(event_type):
		return 1
	if event_type == "double_play":
		return 2
	if event_type == "triple_play":
		return 3
	return 0

func _payload_runs_scored(payload: Dictionary, event_type: String, details: Dictionary) -> int:
	var raw_runs = payload.get("runs_scored", null)
	if raw_runs is Array:
		return raw_runs.size()
	if raw_runs is int or raw_runs is float:
		return int(raw_runs)
	return _placeholder_runs_scored(event_type, details)

func _placeholder_runs_scored(event_type: String, details: Dictionary) -> int:
	var advancements := details.get("runner_advancements", [])
	if advancements is Array:
		var total := 0
		for advancement in advancements:
			if advancement is Dictionary and (bool(advancement.get("scored", false)) or str(advancement.get("end_base", "")).to_upper() == "SCORED"):
				total += 1
		return total
	return 0

func _first_player_id_for_team(team_id: String) -> String:
	if repository == null or team_id.is_empty():
		return ""
	for player in repository.players:
		if player.team_id == team_id:
			return player.id
	return ""

func get_game_state_at_event(game_id: String, event_id: String) -> Dictionary:
	return GameStateSnapshotScript.get_game_state_at_event(_events_for_current_game(), game_id, event_id, _player_names_by_id())

func replay_game_until_sequence(game_id: String, sequence: int) -> Dictionary:
	return GameStateSnapshotScript.replay_game_until_sequence(_events_for_game_id(game_id), sequence, _player_names_by_id())

func _scoreboard_state_for_event(event_id: String) -> Dictionary:
	if current_game == null:
		return _scoreboard_state_for_events([])
	return get_game_state_at_event(current_game.id, event_id)

func _scoreboard_state_for_events(events: Array, sequence_number: int = -1) -> Dictionary:
	return GameStateSnapshotScript.replay_game_until_sequence(events, sequence_number, _player_names_by_id())

func _events_for_game_id(game_id: String) -> Array:
	return _events_for_current_game().filter(func(event: GameEvent) -> bool: return game_id.is_empty() or event.game_id == game_id)

func _player_names_by_id() -> Dictionary:
	var names := {}
	if repository == null:
		return names
	for player in repository.players:
		names[player.id] = player.display_name if not player.display_name.is_empty() else player.id
	return names

func _player_name_for_id(player_id: String) -> String:
	if player_id.is_empty() or repository == null:
		return ""
	var player: Player = repository.find_entity_by_id(player_id, "players")
	return player.display_name if player != null and not player.display_name.is_empty() else player_id

func _on_roster_team_tab_changed(side: String) -> void:
	event_summary_panel.set_selected_event_summary("Showing %s quick roster. Add Player will target this tab's team." % side.capitalize())
	_update_add_player_button_state()

func _update_add_player_button_state() -> void:
	add_player_button.disabled = not team_quick_roster_panel.can_add_player_to_selected_team()
	add_player_button.text = "Add Player" if not add_player_button.disabled else "Add Player (select team)"

func _on_roster_player_selected(player_id: String) -> void:
	event_summary_panel.set_selected_event_summary("Selected roster player: %s" % player_id)

func _on_roster_add_player_requested(team_id: String) -> void:
	_pending_add_team_id = team_id
	add_player_requested.emit(team_id)
	_clear_add_player_dialog()
	_validate_add_player_dialog()
	var team: Team = repository.find_entity_by_id(team_id, "teams") if repository != null else null
	add_player_dialog.title = "Add Player — %s" % _team_name(team)
	add_player_dialog.popup_centered(Vector2i(420, 420))

func _build_add_player_dialog() -> void:
	add_player_dialog = AcceptDialog.new()
	add_player_dialog.title = "Add Player"
	add_player_dialog.min_size = Vector2i(420, 420)
	add_player_dialog.confirmed.connect(_on_add_player_confirmed)
	add_child(add_player_dialog)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_player_dialog.add_child(box)
	jersey_number_field = _add_line_field(box, "Jersey number")
	display_name_field = _add_line_field(box, "Display name")
	position_field = _add_line_field(box, "Position (optional)")
	bats_field = _add_line_field(box, "Bats (optional)")
	throws_field = _add_line_field(box, "Throws (optional)")
	var notes_label := Label.new()
	notes_label.text = "Notes (optional)"
	box.add_child(notes_label)
	notes_field = TextEdit.new()
	notes_field.custom_minimum_size = Vector2(0, 70)
	box.add_child(notes_field)
	validation_label = Label.new()
	validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(validation_label)
	duplicate_warning_label = Label.new()
	duplicate_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(duplicate_warning_label)
	for field in [jersey_number_field, display_name_field, position_field, bats_field, throws_field]:
		field.text_changed.connect(func(_text: String) -> void: _validate_add_player_dialog())
	GameEntryStyle.style_body_label(validation_label)
	GameEntryStyle.style_body_label(duplicate_warning_label)

func _add_line_field(parent: VBoxContainer, label_text: String) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var field := LineEdit.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(field)
	return field

func _clear_add_player_dialog() -> void:
	for field in [jersey_number_field, display_name_field, position_field, bats_field, throws_field]:
		field.text = ""
	notes_field.text = ""

func _validate_add_player_dialog() -> bool:
	var errors: Array[String] = []
	if display_name_field.text.strip_edges().is_empty():
		errors.append("Display name is required.")
	if _pending_add_team_id.strip_edges().is_empty():
		errors.append("Select a Home or Away team before adding a player.")
	var duplicate := repository != null and repository.has_duplicate_jersey_number(_pending_add_team_id, jersey_number_field.text)
	validation_label.text = "\n".join(errors)
	duplicate_warning_label.text = "Warning: another player on this team already uses jersey #%s." % jersey_number_field.text.strip_edges() if duplicate else ""
	add_player_dialog.get_ok_button().disabled = not errors.is_empty()
	return errors.is_empty()

func _on_add_player_confirmed() -> void:
	if not _validate_add_player_dialog():
		add_player_dialog.popup_centered(Vector2i(420, 420))
		return
	var player := repository.create_player_for_team(_pending_add_team_id, {
		"jersey_number": jersey_number_field.text,
		"display_name": display_name_field.text,
		"position": position_field.text,
		"bats": bats_field.text,
		"throws": throws_field.text,
		"notes": notes_field.text,
	})
	if player == null:
		event_summary_panel.set_selected_event_summary("Could not create player for team %s." % _pending_add_team_id)
		return
	SaveManagerScript.save_project(repository)
	_refresh_game_context()
	event_summary_panel.set_selected_event_summary("Added #%s %s to %s roster." % [player.jersey_number, player.display_name, team_quick_roster_panel.get_selected_side().capitalize()])

func _team_name(team: Team) -> String:
	return team.name if team != null and not team.name.is_empty() else "Unknown Team"
