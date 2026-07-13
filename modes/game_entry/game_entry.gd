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
@onready var root_margin_container: MarginContainer = %RootMarginContainer
@onready var main_content_row: HBoxContainer = $RootMarginContainer/MainVBox/MainContentRow
@onready var left_dock: PanelContainer = %LeftDock
@onready var center_dock: PanelContainer = %CenterDock
@onready var right_dock: PanelContainer = %RightDock
@onready var event_key_panel: EventKeyPanel = %EventKeyPanel
@onready var team_quick_roster_panel: TeamQuickRosterPanel = %TeamQuickRosterPanel
@onready var edit_batting_lineup_button: Button = %EditBattingLineupButton
@onready var add_player_button: Button = %AddPlayerButton
@onready var workspace_panel: WorkspacePanel = %WorkspacePanel
@onready var event_summary_panel: EventSummaryPanel = %EventSummaryPanel
@onready var skinny_event_history_panel: SkinnyEventHistoryPanel = %SkinnyEventHistoryPanel
@onready var compact_scoreboard_panel: CompactScoreboardPanel = %CompactScoreboardPanel
@onready var active_pitcher_panel: ActivePitcherPanel = %ActivePitcherPanel
@onready var workspace_label: Label = %WorkspaceTitleLabel
@onready var event_history_label: Label = %EventHistoryLabel
@onready var workspace_placeholder: Label = %WorkspaceContextLabel

var repository: DataRepository
var current_game: Game
var add_player_dialog: AcceptDialog
var jersey_number_field: LineEdit
var first_name_field: LineEdit
var last_name_field: LineEdit
var position_field: LineEdit
var bats_field: LineEdit
var throws_field: LineEdit
var notes_field: TextEdit
var validation_label: Label
var duplicate_warning_label: Label
var _pending_add_team_id = ""
var _editing_player_id = ""
var _selected_player_id = ""
var _selected_event_id = ""
var _current_payload: Dictionary = {}
var _current_validation_messages: Array = []
var _editing_event_id = ""
var _syncing_event_selection = false
var _undo_event_actions: Array[Dictionary] = []
var _redo_event_actions: Array[Dictionary] = []
var lineup_dialog: AcceptDialog
var lineup_selectors: Array[OptionButton] = []
var _editing_lineup_side = ""
var starting_pitcher_dialog: AcceptDialog
var home_starting_pitcher_selector: OptionButton
var away_starting_pitcher_selector: OptionButton
var starting_pitcher_warning_label: Label

const SHORTCUT_EVENT_TYPES = {
	KEY_S: "single",
	KEY_D: "double",
	KEY_T: "triple",
	KEY_H: "home_run",
	KEY_W: "walk",
	KEY_K: "strikeout",
	KEY_G: "groundout",
	KEY_F: "flyout",
	KEY_E: "reached_on_error",
	KEY_C: "fielders_choice",
	KEY_B: "stolen_base",
	KEY_P: "pitching_change",
	KEY_U: "pinch_hitter",
}

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_style()
	_apply_responsive_layout()
	_build_add_player_dialog()
	_build_lineup_dialog()
	_build_starting_pitcher_dialog()
	event_key_panel.event_type_selected.connect(_on_event_key_pressed)
	workspace_panel.event_payload_changed.connect(_on_workspace_event_payload_changed)
	workspace_panel.event_selected.connect(_on_workspace_event_selected)
	workspace_panel.event_edit_requested.connect(_on_workspace_event_edit_requested)
	workspace_panel.event_delete_requested.connect(_on_workspace_event_delete_requested)
	workspace_panel.event_creation_cancel_requested.connect(_on_workspace_event_creation_cancel_requested)
	event_summary_panel.confirm_requested.connect(_on_event_summary_confirm_requested)
	event_summary_panel.cancel_requested.connect(_on_event_summary_cancel_requested)
	event_summary_panel.edit_requested.connect(_on_event_summary_edit_requested)
	skinny_event_history_panel.event_selected.connect(_on_skinny_event_history_selected)
	team_quick_roster_panel.roster_team_tab_changed.connect(_on_roster_team_tab_changed)
	team_quick_roster_panel.player_selected.connect(_on_roster_player_selected)
	team_quick_roster_panel.add_player_requested.connect(_on_roster_add_player_requested)
	edit_batting_lineup_button.pressed.connect(_on_edit_batting_lineup_pressed)
	add_player_button.pressed.connect(team_quick_roster_panel.request_add_player)
	active_pitcher_panel.select_starting_pitchers_requested.connect(_on_select_starting_pitchers_requested)
	_load_repository()
	_refresh_game_context()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if _is_text_entry_focused():
		return
	if key_event.ctrl_pressed and not key_event.alt_pressed and not key_event.shift_pressed:
		match key_event.keycode:
			KEY_Z:
				undo_last_event()
				get_viewport().set_input_as_handled()
			KEY_Y:
				redo_last_event()
				get_viewport().set_input_as_handled()
		return
	if key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
		return
	match key_event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if event_summary_panel.can_confirm_event():
				_on_event_summary_confirm_requested()
				get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if event_summary_panel.has_active_event():
				_on_event_summary_cancel_requested()
				get_viewport().set_input_as_handled()
		_:
			if SHORTCUT_EVENT_TYPES.has(key_event.keycode):
				if event_key_panel.activate_event_type(str(SHORTCUT_EVENT_TYPES[key_event.keycode])):
					get_viewport().set_input_as_handled()

func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	var viewport_size = get_viewport_rect().size
	var width = viewport_size.x
	var height = viewport_size.y
	var compact = width <= 1280.0 or height <= 720.0
	var ultra_compact = width <= 1000.0 or height <= 560.0
	var margin = 8 if ultra_compact else 12 if compact else 16
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		root_margin_container.add_theme_constant_override(side, margin)
	main_content_row.add_theme_constant_override(&"separation", 6 if ultra_compact else 8 if compact else 12)
	left_dock.custom_minimum_size.x = 190.0 if ultra_compact else 220.0 if compact else 260.0
	center_dock.custom_minimum_size.x = 280.0 if ultra_compact else 340.0 if compact else 420.0
	right_dock.custom_minimum_size.x = 170.0 if ultra_compact else 200.0 if compact else 240.0
	team_quick_roster_panel.custom_minimum_size.y = 150.0 if ultra_compact else 180.0 if compact else 220.0
	event_summary_panel.custom_minimum_size.y = 108.0 if ultra_compact else 126.0 if compact else 150.0
	skinny_event_history_panel.custom_minimum_size.y = 150.0 if ultra_compact else 180.0 if compact else 220.0
	compact_scoreboard_panel.custom_minimum_size.y = 150.0 if ultra_compact else 180.0 if compact else 220.0
	event_key_panel.apply_responsive_density(compact, ultra_compact)
	workspace_panel.custom_minimum_size.y = 230.0 if ultra_compact else 280.0 if compact else 320.0

func _is_text_entry_focused() -> bool:
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		return false
	return focus_owner is LineEdit or focus_owner is TextEdit

func undo_last_event() -> void:
	if _undo_event_actions.is_empty():
		event_summary_panel.set_validation_messages([{ "severity": "info", "message": "Nothing to undo in the current event log." }])
		return
	var action = _undo_event_actions.pop_back()
	if not _apply_event_history_action(action, true):
		_undo_event_actions.append(action)
		event_summary_panel.set_validation_messages([{ "severity": "error", "message": "Could not undo the last event-log action." }])
		return
	_redo_event_actions.append(action)
	_complete_event_history_action("Undid %s." % _event_history_action_label(action, true), _selection_after_event_history_action(action, true))

func redo_last_event() -> void:
	if _redo_event_actions.is_empty():
		event_summary_panel.set_validation_messages([{ "severity": "info", "message": "Nothing to redo in the current event log." }])
		return
	var action = _redo_event_actions.pop_back()
	if not _apply_event_history_action(action, false):
		_redo_event_actions.append(action)
		event_summary_panel.set_validation_messages([{ "severity": "error", "message": "Could not redo the event-log action." }])
		return
	_undo_event_actions.append(action)
	_complete_event_history_action("Redid %s." % _event_history_action_label(action, false), _selection_after_event_history_action(action, false))

func _record_event_history_action(action: Dictionary) -> void:
	_undo_event_actions.append(action.duplicate(true))
	_redo_event_actions.clear()

func _apply_event_history_action(action: Dictionary, undo: bool) -> bool:
	if repository == null:
		return false
	var action_type = str(action.get("type", ""))
	match action_type:
		"create":
			var created_event: GameEvent = _event_from_history_snapshot(action.get("after", {}))
			if created_event == null:
				return false
			return repository.remove_game_event(created_event.id) if undo else repository.append_game_event(created_event)
		"update":
			var snapshot = action.get("before", {}) if undo else action.get("after", {})
			var event: GameEvent = _event_from_history_snapshot(snapshot)
			return event != null and repository.update_game_event(event)
		"delete":
			var deleted_event: GameEvent = _event_from_history_snapshot(action.get("before", {}))
			if deleted_event == null:
				return false
			return repository.append_game_event(deleted_event) if undo else repository.remove_game_event(deleted_event.id)
	return false

func _complete_event_history_action(message: String, selected_event_id: String) -> void:
	SaveManagerScript.save_project(repository)
	_editing_event_id = ""
	_current_payload.clear()
	_current_validation_messages.clear()
	_selected_event_id = selected_event_id
	_refresh_game_context()
	workspace_panel.show_review_mode()
	if selected_event_id.is_empty():
		workspace_panel.clear_event_selection()
		skinny_event_history_panel.clear_selection()
		compact_scoreboard_panel.set_state(_scoreboard_state_for_events(_events_for_current_game()))
		_update_active_pitcher_panel("")
		event_summary_panel.set_validation_messages([{ "severity": "info", "message": message }])
	else:
		_select_event(selected_event_id, "history_action")
		event_summary_panel.set_validation_messages([{ "severity": "info", "message": message }])

func _event_history_action_label(action: Dictionary, undo: bool) -> String:
	var action_type = str(action.get("type", ""))
	var snapshot = action.get("after", {}) if action_type == "create" or not undo else action.get("before", {})
	var event_id = str(Dictionary(snapshot).get("id", Dictionary(snapshot).get("event_id", ""))) if snapshot is Dictionary else ""
	match action_type:
		"create":
			return "created event %s" % event_id
		"update":
			return "event edit %s" % event_id
		"delete":
			return "deleted event %s" % event_id
	return "event-log action"

func _selection_after_event_history_action(action: Dictionary, undo: bool) -> String:
	var action_type = str(action.get("type", ""))
	if (action_type == "create" and undo) or (action_type == "delete" and not undo):
		var events = _events_for_current_game()
		return events.back().id if not events.is_empty() else ""
	var snapshot = action.get("before", {}) if undo else action.get("after", {})
	return str(Dictionary(snapshot).get("id", Dictionary(snapshot).get("event_id", ""))) if snapshot is Dictionary else ""

func _event_history_snapshot(event: GameEvent) -> Dictionary:
	return event.to_dict().duplicate(true) if event != null else {}

func _event_from_history_snapshot(snapshot: Variant) -> GameEvent:
	if not (snapshot is Dictionary):
		return null
	return GameEventScript.from_dict(Dictionary(snapshot).duplicate(true))

func _apply_style() -> void:
	GameEntryStyle.apply_shell_style(
		self,
		background,
		[left_dock, center_dock, right_dock],
		[event_key_panel, team_quick_roster_panel, workspace_panel, skinny_event_history_panel, compact_scoreboard_panel],
		[workspace_label, event_history_label],
		[workspace_placeholder],
		[edit_batting_lineup_button, add_player_button]
	)

func _load_repository() -> void:
	repository = SaveManagerScript.load_project()
	if repository == null:
		repository = SaveManagerScript.new_project()
		var sample = SampleDataFactoryScript.create_sample_competition()
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
		team_quick_roster_panel.set_active_batter_ids("", "")
		_update_add_player_button_state()
		skinny_event_history_panel.clear()
		compact_scoreboard_panel.clear()
		active_pitcher_panel.clear()
		event_summary_panel.set_idle()
		return
	team_quick_roster_panel.set_team_ids(current_game.home_team_id, current_game.away_team_id)
	team_quick_roster_panel.set_home_roster(_players_for_team(current_game.home_team_id))
	team_quick_roster_panel.set_away_roster(_players_for_team(current_game.away_team_id))
	_load_batting_lineups_for_current_game()
	team_quick_roster_panel.set_active_batter_ids(_active_batter_id_for_team(current_game.home_team_id), _active_batter_id_for_team(current_game.away_team_id))
	_update_add_player_button_state()
	var home_team: Team = repository.find_entity_by_id(current_game.home_team_id, "teams")
	var away_team: Team = repository.find_entity_by_id(current_game.away_team_id, "teams")
	var events = _events_for_current_game()
	var event_context = _event_log_context()
	workspace_panel.set_events(events, event_context)
	skinny_event_history_panel.set_events(events, event_context)
	compact_scoreboard_panel.set_state(_scoreboard_state_for_events(events))
	_update_active_pitcher_panel(_selected_event_id)
	event_summary_panel.set_idle()
	if _starting_pitchers_missing():
		call_deferred("_open_starting_pitcher_dialog", true)

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
	var players_by_id = {}
	if repository != null:
		for player in repository.players:
			players_by_id[player.id] = player
	return {"players_by_id": players_by_id}

func _on_event_key_pressed(event_type: String) -> void:
	_editing_event_id = ""
	_selected_player_id = ""
	team_quick_roster_panel.clear_selection()
	_current_payload.clear()
	_current_validation_messages.clear()
	workspace_panel.show_create_event_mode(event_type, _build_workspace_game_context())
	event_summary_panel.set_preview_text("Drafting event payload for: %s." % event_type.replace("_", " ").capitalize())
	event_summary_panel.set_validation_messages([{ "severity": "info", "message": "Complete the event form, then review validation before confirming." }])
	event_summary_panel.set_active(false)
	event_key_selected.emit(event_type)

func _on_workspace_event_payload_changed(payload: Dictionary) -> void:
	_current_payload = payload.duplicate(true)
	var preview = EventSummaryFormatterScript.summarize(_current_payload)
	_current_validation_messages = EventValidatorScript.validate_event_payload(_current_payload)
	event_summary_panel.set_preview_text(preview)
	event_summary_panel.set_validation_messages(_current_validation_messages)
	event_summary_panel.set_active(not EventValidatorScript.has_errors(_current_validation_messages))

func _on_skinny_event_history_selected(event_id: String) -> void:
	_select_event(event_id, "skinny_history")

func _on_workspace_event_selected(event_id: String) -> void:
	_select_event(event_id, "event_log")

func _select_event(event_id: String, source: String = "") -> void:
	if _syncing_event_selection or event_id.strip_edges().is_empty():
		return
	_syncing_event_selection = true
	_selected_player_id = ""
	team_quick_roster_panel.clear_selection()
	_selected_event_id = event_id
	workspace_panel.show_review_mode()
	match source:
		"skinny_history":
			workspace_panel.scroll_to_event(event_id, false)
		"event_log":
			skinny_event_history_panel.select_event_silent(event_id)
		_:
			workspace_panel.scroll_to_event(event_id, false)
			skinny_event_history_panel.select_event_silent(event_id)
	event_summary_panel.set_selected_event_summary(_summary_for_event(event_id))
	compact_scoreboard_panel.set_state(_scoreboard_state_for_event(event_id))
	_update_active_pitcher_panel(event_id)
	_syncing_event_selection = false

func _on_workspace_event_edit_requested(event_id: String) -> void:
	if _is_current_game_finalized():
		event_summary_panel.set_validation_messages([{ "severity": "warning", "message": "This game is marked Final; editing is locked until a formal unlock workflow is added. TODO: add finalized-game unlock/override flow." }])
		return
	var event = _find_current_game_event(event_id)
	if event == null:
		event_summary_panel.set_validation_messages([{ "severity": "error", "message": "Could not find event %s in the current game log." % event_id }])
		return
	_selected_player_id = ""
	team_quick_roster_panel.clear_selection()
	_selected_event_id = event_id
	_editing_event_id = event_id
	_current_payload = _payload_from_game_event(event)
	_current_validation_messages = EventValidatorScript.validate_event_payload(_current_payload)
	workspace_panel.show_edit_event_mode(event_id, _current_payload, _build_workspace_game_context_for_event(event))
	skinny_event_history_panel.select_event_silent(event_id)
	event_summary_panel.set_preview_text(EventSummaryFormatterScript.summarize(_current_payload))
	event_summary_panel.set_validation_messages(_current_validation_messages)
	event_summary_panel.set_active(not EventValidatorScript.has_errors(_current_validation_messages))

func _on_workspace_event_delete_requested(event_id: String) -> void:
	if _is_current_game_finalized():
		event_summary_panel.set_validation_messages([{ "severity": "warning", "message": "This game is marked Final; deleting is locked until a formal unlock workflow is added." }])
		return
	var event = _find_current_game_event(event_id)
	if event == null:
		event_summary_panel.set_validation_messages([{ "severity": "error", "message": "Could not find event %s in the current game log." % event_id }])
		return
	var events = _events_for_current_game()
	if events.is_empty() or events.back().id != event_id:
		event_summary_panel.set_validation_messages([{ "severity": "warning", "message": "Only the latest event can be deleted." }])
		return
	var history_action = {"type": "delete", "before": _event_history_snapshot(event), "after": {}}
	if not repository.remove_game_event(event_id):
		event_summary_panel.set_validation_messages([{ "severity": "error", "message": "Could not delete event %s from the current game log." % event_id }])
		return
	_record_event_history_action(history_action)
	SaveManagerScript.save_project(repository)
	_selected_event_id = ""
	_editing_event_id = ""
	_current_payload.clear()
	_current_validation_messages.clear()
	_refresh_game_context()
	workspace_panel.show_review_mode()
	var remaining_events = _events_for_current_game()
	if remaining_events.is_empty():
		event_summary_panel.set_validation_messages([{ "severity": "info", "message": "Deleted event %s." % event_id }])
	else:
		_select_event(remaining_events.back().id, "delete")
		event_summary_panel.set_validation_messages([{ "severity": "info", "message": "Deleted event %s." % event_id }])

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
	var existing_event = _find_current_game_event(_editing_event_id) if not _editing_event_id.is_empty() else null
	_current_payload = _payload_with_current_quick_roster_batter(_current_payload, existing_event)
	_current_validation_messages = EventValidatorScript.validate_event_payload(_current_payload)
	if EventValidatorScript.has_errors(_current_validation_messages):
		event_summary_panel.set_validation_messages(_current_validation_messages)
		event_summary_panel.set_active(false)
		return
	var history_action = {
		"type": "update" if existing_event != null else "create",
		"before": _event_history_snapshot(existing_event),
	}
	var event = _game_event_from_payload(_current_payload, existing_event)
	var saved = repository.update_game_event(event) if existing_event != null else repository.append_game_event(event)
	if not saved:
		var action = "update" if existing_event != null else "append"
		event_summary_panel.set_validation_messages([{ "severity": "error", "message": "Could not %s the event in the current game log." % action }])
		return
	history_action["after"] = _event_history_snapshot(event)
	_record_event_history_action(history_action)
	SaveManagerScript.save_project(repository)
	_selected_event_id = event.id
	_editing_event_id = ""
	_current_payload.clear()
	_current_validation_messages.clear()
	_refresh_game_context()
	workspace_panel.show_review_mode()
	_select_event(event.id, "commit")

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
	if not _selected_player_id.is_empty():
		_open_edit_player_dialog(_selected_player_id)
		return
	var event_id = _selected_event_id
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
	var payload = event.to_dict()
	payload["event_id"] = event.id
	payload["mode"] = "editing_event"
	return payload

func _build_workspace_game_context_for_event(event: GameEvent) -> Dictionary:
	var context = _build_workspace_game_context()
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
	var events = _events_for_current_game()
	var state = _scoreboard_state_for_events(events)
	var half = str(state.get("half", "Top"))
	var offense_team_id = current_game.away_team_id if half.to_lower() == "top" else current_game.home_team_id
	var defense_team_id = current_game.home_team_id if half.to_lower() == "top" else current_game.away_team_id
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
		"batter_id": _active_batter_id_from_quick_roster(offense_team_id),
		"pitcher_id": _active_pitcher_id_for_defense_side(defense_team_id, events),
		"offensive_lineup": _players_for_team(offense_team_id),
		"defensive_players": _players_for_team(defense_team_id),
	}

func _payload_with_current_quick_roster_batter(payload: Dictionary, existing_event: GameEvent = null) -> Dictionary:
	var output = payload.duplicate(true)
	if existing_event != null:
		return output
	var offense_team_id = str(output.get("offense_team_id", ""))
	if offense_team_id.is_empty() and output.get("game_context", {}) is Dictionary:
		offense_team_id = str(output["game_context"].get("offense_team_id", ""))
	var active_batter_id = _active_batter_id_from_quick_roster(offense_team_id)
	if active_batter_id.is_empty():
		return output
	output["batter_id"] = active_batter_id
	if output.get("game_context", {}) is Dictionary:
		var context = Dictionary(output["game_context"]).duplicate(true)
		context["batter_id"] = active_batter_id
		output["game_context"] = context
	return output

func _active_batter_id_from_quick_roster(team_id: String) -> String:
	if team_id.strip_edges().is_empty():
		return ""
	var marked_batter_id = team_quick_roster_panel.get_active_batter_id_for_team_id(team_id)
	if not marked_batter_id.strip_edges().is_empty():
		return marked_batter_id
	var calculated_batter_id = _active_batter_id_for_team(team_id)
	return calculated_batter_id if not calculated_batter_id.strip_edges().is_empty() else _first_player_id_for_team(team_id)

func _game_event_from_payload(payload: Dictionary, existing_event: GameEvent = null) -> GameEvent:
	var events = _events_for_current_game()
	var next_sequence = events.size() + 1
	for existing in events:
		next_sequence = max(next_sequence, existing.sequence_number + 1)
	var event_id = existing_event.id if existing_event != null else _next_game_event_id()
	var event = GameEventScript.new(event_id, current_game.id)
	var event_type = _normalize_event_type(str(payload.get("event_type", "manual_correction")))
	var details = Dictionary(payload.get("details", {})).duplicate(true) if payload.get("details", {}) is Dictionary else {}
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
	if event_type == "pitching_change":
		var pitching_change = Dictionary(details.get("pitching_change", details)) if details is Dictionary else {}
		event.pitcher_id = str(pitching_change.get("incoming_pitcher_id", event.pitcher_id))
	event.offense_team_id = str(payload.get("offense_team_id", ""))
	event.offensive_team_id = event.offense_team_id
	event.defense_team_id = str(payload.get("defense_team_id", ""))
	event.defensive_team_id = event.defense_team_id
	event.outs_before = int(payload.get("outs_before", 0))
	event.outs_added = _placeholder_outs_added(event_type, details)
	var requested_outs_after = int(payload.get("outs_after", event.outs_before + event.outs_added))
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
	var index = repository.game_events.size() + 1 if repository != null else 1
	while repository != null and repository.find_entity_by_id("event_%03d" % index, "game_events") != null:
		index += 1
	return "event_%03d" % index

func _normalize_event_type(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")

func _legacy_event_label(event_type: String) -> String:
	var labels = {"single":"Single", "double":"Double", "triple":"Triple", "home_run":"Home run", "walk":"Walk", "hit_by_pitch":"Hit by pitch", "reached_on_error":"Reached on error", "fielders_choice":"Fielder's choice", "stolen_base":"Stolen base"}
	return str(labels.get(event_type, event_type.replace("_", " ").capitalize()))

func _placeholder_outs_added(event_type: String, details: Dictionary) -> int:
	var manual_overrides = Dictionary(details.get("manual_overrides", {})) if details.get("manual_overrides", {}) is Dictionary else {}
	if manual_overrides.has("outs"):
		return max(0, int(manual_overrides.get("outs", 0)))
	var explicit_outs = _explicit_outs_added_from_details(details)
	if explicit_outs >= 0:
		return explicit_outs
	var advancement_outs = _outs_added_from_runner_advancements(details.get("runner_advancements", []))
	if advancement_outs > 0:
		return advancement_outs
	if details.has("out_assignments") and details["out_assignments"] is Array and not details["out_assignments"].is_empty():
		return min(3, details["out_assignments"].size())
	match event_type:
		"strikeout", "groundout", "flyout", "fielders_choice", "sacrifice_bunt", "sacrifice_fly", "caught_stealing":
			return 1
		"double_play":
			return 2
		"triple_play":
			return 3
		"dropped_third_strike":
			return 1 if _dropped_third_strike_batter_is_out(details) else 0
		"pickoff":
			return 1 if _pickoff_runner_is_out(details) else 0
	return 0

func _explicit_outs_added_from_details(details: Dictionary) -> int:
	for source in [details, Dictionary(details.get("event_details", {})) if details.get("event_details", {}) is Dictionary else {}]:
		if source.has("outs_added") and str(source.get("outs_added", "")).strip_edges().is_valid_int():
			return max(0, int(source.get("outs_added", 0)))
		for section in source.values():
			if section is Dictionary and section.has("outs_added") and str(section.get("outs_added", "")).strip_edges().is_valid_int():
				return max(0, int(section.get("outs_added", 0)))
	return -1

func _outs_added_from_runner_advancements(advancements: Variant) -> int:
	if not (advancements is Array):
		return 0
	var total = 0
	for advancement in advancements:
		if advancement is Dictionary:
			var end_base = str(advancement.get("end_base", "")).strip_edges().to_upper()
			if bool(advancement.get("out", false)) or end_base == "OUT":
				total += 1
	return min(3, total)

func _dropped_third_strike_batter_is_out(details: Dictionary) -> bool:
	var flat = _flatten_detail_sections(details)
	var result = str(flat.get("batter_reached_or_out", flat.get("result", ""))).strip_edges().to_lower()
	return result in ["out", "batter_out", "retired"]

func _pickoff_runner_is_out(details: Dictionary) -> bool:
	var flat = _flatten_detail_sections(details)
	return str(flat.get("safe_or_out", "")).strip_edges().to_lower() in ["out", "caught", "retired"]

func _flatten_detail_sections(details: Dictionary) -> Dictionary:
	var output = {}
	for key in details.keys():
		if details[key] is Dictionary:
			for nested_key in details[key].keys():
				if details[key][nested_key] is Dictionary:
					for leaf_key in details[key][nested_key].keys():
						output[leaf_key] = details[key][nested_key][leaf_key]
				else:
					output[nested_key] = details[key][nested_key]
		else:
			output[key] = details[key]
	return output

func _payload_runs_scored(payload: Dictionary, event_type: String, details: Dictionary) -> int:
	var raw_runs = payload.get("runs_scored", null)
	if raw_runs is Array:
		return raw_runs.size()
	if raw_runs is int or raw_runs is float:
		return int(raw_runs)
	return _placeholder_runs_scored(event_type, details)

func _placeholder_runs_scored(event_type: String, details: Dictionary) -> int:
	var advancements = details.get("runner_advancements", [])
	if advancements is Array:
		var total = 0
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
	return GameStateSnapshotScript.get_game_state_at_event(_events_for_current_game(), game_id, event_id, _player_names_by_id(), _starting_pitcher_ids())

func replay_game_until_sequence(game_id: String, sequence: int) -> Dictionary:
	return GameStateSnapshotScript.replay_game_until_sequence(_events_for_game_id(game_id), sequence, _player_names_by_id(), _starting_pitcher_ids())

func _scoreboard_state_for_event(event_id: String) -> Dictionary:
	if current_game == null:
		return _scoreboard_state_for_events([])
	return get_game_state_at_event(current_game.id, event_id)

func _scoreboard_state_for_events(events: Array, sequence_number: int = -1) -> Dictionary:
	return GameStateSnapshotScript.replay_game_until_sequence(events, sequence_number, _player_names_by_id(), _starting_pitcher_ids())

func _events_for_game_id(game_id: String) -> Array:
	return _events_for_current_game().filter(func(event: GameEvent) -> bool: return game_id.is_empty() or event.game_id == game_id)

func _player_names_by_id() -> Dictionary:
	var names = {}
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

func _active_batter_id_for_team(team_id: String) -> String:
	if current_game == null or team_id.strip_edges().is_empty():
		return ""
	var lineup = team_quick_roster_panel.get_lineup_for_team_id(team_id)
	var filled_lineup: Array[String] = []
	for player_id in lineup:
		if not str(player_id).strip_edges().is_empty():
			filled_lineup.append(str(player_id))
	if filled_lineup.is_empty():
		return ""
	var plate_appearances = 0
	for event in _events_for_current_game():
		if str(event.offense_team_id) == team_id and not str(event.batter_id).strip_edges().is_empty():
			plate_appearances += 1
	return filled_lineup[plate_appearances % filled_lineup.size()]

func _on_edit_batting_lineup_pressed() -> void:
	_editing_lineup_side = team_quick_roster_panel.get_selected_side()
	_populate_lineup_dialog()
	var team: Team = repository.find_entity_by_id(team_quick_roster_panel.get_selected_team_id(), "teams") if repository != null else null
	lineup_dialog.title = "Edit Batting Lineup — %s" % _team_name(team)
	lineup_dialog.popup_centered(Vector2i(480, 520))

func _build_lineup_dialog() -> void:
	lineup_dialog = AcceptDialog.new()
	lineup_dialog.title = "Edit Batting Lineup"
	lineup_dialog.min_size = Vector2i(480, 520)
	lineup_dialog.confirmed.connect(_on_lineup_confirmed)
	add_child(lineup_dialog)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	lineup_dialog.add_child(box)
	var help = Label.new()
	help.text = "Choose one unique roster player for each batting order spot."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	GameEntryStyle.style_body_label(help)
	for index in range(9):
		var selector = OptionButton.new()
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector.item_selected.connect(func(_item_index: int) -> void: _refresh_lineup_selector_options())
		lineup_selectors.append(selector)
		var row = HBoxContainer.new()
		var label = Label.new()
		label.custom_minimum_size.x = 64
		label.text = "Spot %d" % (index + 1)
		row.add_child(label)
		row.add_child(selector)
		box.add_child(row)

func _populate_lineup_dialog() -> void:
	var current_lineup = team_quick_roster_panel.get_lineup_for_side(_editing_lineup_side)
	for index in range(lineup_selectors.size()):
		lineup_selectors[index].set_meta("selected_player_id", str(current_lineup[index]) if index < current_lineup.size() else "")
	_refresh_lineup_selector_options()

func _refresh_lineup_selector_options() -> void:
	var selected_ids: Array[String] = []
	for selector in lineup_selectors:
		if selector.selected >= 0:
			selector.set_meta("selected_player_id", str(selector.get_item_metadata(selector.selected)))
		var selected_id = str(selector.get_meta("selected_player_id", ""))
		if not selected_id.is_empty():
			selected_ids.append(selected_id)
	var roster = team_quick_roster_panel.get_roster_for_side(_editing_lineup_side)
	for selector in lineup_selectors:
		var current_id = str(selector.get_meta("selected_player_id", ""))
		selector.clear()
		selector.add_item("-- Select player --")
		selector.set_item_metadata(0, "")
		for player in roster:
			var player_id = player.id
			if player_id != current_id and selected_ids.has(player_id):
				continue
			selector.add_item("#%s %s" % [player.jersey_number if not player.jersey_number.is_empty() else "--", player.display_name])
			selector.set_item_metadata(selector.get_item_count() - 1, player_id)
		for item_index in range(selector.get_item_count()):
			if str(selector.get_item_metadata(item_index)) == current_id:
				selector.select(item_index)
				break

func _on_lineup_confirmed() -> void:
	var lineup: Array[String] = []
	for selector in lineup_selectors:
		lineup.append(str(selector.get_meta("selected_player_id", "")))
	team_quick_roster_panel.set_lineup_for_side(_editing_lineup_side, lineup)
	_save_batting_lineup_for_current_game(_editing_lineup_side, lineup)
	if current_game != null:
		team_quick_roster_panel.set_active_batter_ids(_active_batter_id_for_team(current_game.home_team_id), _active_batter_id_for_team(current_game.away_team_id))
	event_summary_panel.set_selected_event_summary("Updated %s batting lineup." % _editing_lineup_side.capitalize())

func _load_batting_lineups_for_current_game() -> void:
	if current_game == null:
		return
	team_quick_roster_panel.set_lineup_for_side("home", current_game.home_batting_lineup)
	team_quick_roster_panel.set_lineup_for_side("away", current_game.away_batting_lineup)

func _save_batting_lineup_for_current_game(side: String, lineup: Array) -> void:
	if current_game == null:
		return
	var normalized_side = side.to_lower()
	var saved_lineup: Array[String] = []
	for index in range(9):
		saved_lineup.append(str(lineup[index]) if index < lineup.size() else "")
	if normalized_side == "home":
		current_game.home_batting_lineup = saved_lineup
	elif normalized_side == "away":
		current_game.away_batting_lineup = saved_lineup
	else:
		return
	SaveManagerScript.save_project(repository)

func _on_roster_team_tab_changed(side: String) -> void:
	_selected_player_id = ""
	event_summary_panel.set_selected_event_summary("Showing %s quick roster. Add Player will target this tab's team." % side.capitalize())
	_update_add_player_button_state()

func _update_add_player_button_state() -> void:
	var team_unavailable = not team_quick_roster_panel.can_add_player_to_selected_team()
	add_player_button.disabled = team_unavailable
	add_player_button.text = "Add Player" if not add_player_button.disabled else "Add Player (select team)"
	edit_batting_lineup_button.disabled = team_unavailable
	edit_batting_lineup_button.text = "Edit Batting Lineup" if not edit_batting_lineup_button.disabled else "Edit Lineup (select team)"

func _on_roster_player_selected(player_id: String) -> void:
	var player: Player = repository.find_entity_by_id(player_id, "players") if repository != null else null
	if player == null:
		event_summary_panel.set_validation_messages([{ "severity": "error", "message": "Could not find selected roster player %s." % player_id }])
		return
	_selected_event_id = ""
	_editing_event_id = ""
	_current_payload.clear()
	_current_validation_messages.clear()
	_selected_player_id = player_id
	workspace_panel.clear_event_selection()
	skinny_event_history_panel.clear_selection()
	compact_scoreboard_panel.set_state(_scoreboard_state_for_events(_events_for_current_game()))
	event_summary_panel.set_selected_event_summary(_summary_for_player(player))

func _on_roster_add_player_requested(team_id: String) -> void:
	_pending_add_team_id = team_id
	_editing_player_id = ""
	add_player_requested.emit(team_id)
	_clear_add_player_dialog()
	_validate_add_player_dialog()
	var team: Team = repository.find_entity_by_id(team_id, "teams") if repository != null else null
	add_player_dialog.title = "Add Player — %s" % _team_name(team)
	add_player_dialog.popup_centered(Vector2i(420, 420))

func _open_edit_player_dialog(player_id: String) -> void:
	var player: Player = repository.find_entity_by_id(player_id, "players") if repository != null else null
	if player == null:
		event_summary_panel.set_validation_messages([{ "severity": "error", "message": "Could not find selected roster player %s." % player_id }])
		return
	_editing_player_id = player.id
	_pending_add_team_id = player.team_id
	_populate_player_dialog(player)
	_validate_add_player_dialog()
	var team: Team = repository.find_entity_by_id(player.team_id, "teams") if repository != null else null
	add_player_dialog.title = "Edit Player — %s" % _team_name(team)
	add_player_dialog.popup_centered(Vector2i(420, 420))

func _build_add_player_dialog() -> void:
	add_player_dialog = AcceptDialog.new()
	add_player_dialog.title = "Add Player"
	add_player_dialog.min_size = Vector2i(420, 420)
	add_player_dialog.confirmed.connect(_on_add_player_confirmed)
	add_child(add_player_dialog)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_player_dialog.add_child(box)
	jersey_number_field = _add_line_field(box, "Jersey number")
	first_name_field = _add_line_field(box, "First name")
	last_name_field = _add_line_field(box, "Last name")
	position_field = _add_line_field(box, "Position (optional)")
	bats_field = _add_line_field(box, "Bats (optional)")
	throws_field = _add_line_field(box, "Throws (optional)")
	var notes_label = Label.new()
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
	for field in [jersey_number_field, first_name_field, last_name_field, position_field, bats_field, throws_field]:
		field.text_changed.connect(func(_text: String) -> void: _validate_add_player_dialog())
	GameEntryStyle.style_body_label(validation_label)
	GameEntryStyle.style_body_label(duplicate_warning_label)

func _add_line_field(parent: VBoxContainer, label_text: String) -> LineEdit:
	var label = Label.new()
	label.text = label_text
	parent.add_child(label)
	var field = LineEdit.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(field)
	return field

func _clear_add_player_dialog() -> void:
	for field in [jersey_number_field, first_name_field, last_name_field, position_field, bats_field, throws_field]:
		field.text = ""
	notes_field.text = ""

func _populate_player_dialog(player: Player) -> void:
	jersey_number_field.text = player.jersey_number
	first_name_field.text = player.first_name
	last_name_field.text = player.last_name
	position_field.text = ", ".join(player.positions)
	bats_field.text = player.bats
	throws_field.text = player.throws_hand
	notes_field.text = player.notes

func _validate_add_player_dialog() -> bool:
	var errors: Array[String] = []
	if last_name_field.text.strip_edges().is_empty():
		errors.append("Last name is required.")
	if _pending_add_team_id.strip_edges().is_empty():
		errors.append("Select a Home or Away team before adding a player.")
	var duplicate = repository != null and _has_duplicate_jersey_number_for_other_player(_pending_add_team_id, jersey_number_field.text, _editing_player_id)
	validation_label.text = "\n".join(errors)
	duplicate_warning_label.text = "Warning: another player on this team already uses jersey #%s." % jersey_number_field.text.strip_edges() if duplicate else ""
	add_player_dialog.get_ok_button().disabled = not errors.is_empty()
	return errors.is_empty()

func _on_add_player_confirmed() -> void:
	if not _validate_add_player_dialog():
		add_player_dialog.popup_centered(Vector2i(420, 420))
		return
	if not _editing_player_id.is_empty():
		_on_edit_player_confirmed()
		return
	var player = repository.create_player_for_team(_pending_add_team_id, {
		"jersey_number": jersey_number_field.text,
		"first_name": first_name_field.text,
		"last_name": last_name_field.text,
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

func _on_edit_player_confirmed() -> void:
	var player: Player = repository.find_entity_by_id(_editing_player_id, "players") if repository != null else null
	if player == null:
		event_summary_panel.set_selected_event_summary("Could not update missing player %s." % _editing_player_id)
		return
	player.jersey_number = jersey_number_field.text.strip_edges()
	player.first_name = first_name_field.text.strip_edges()
	player.last_name = last_name_field.text.strip_edges()
	player.display_name = player.last_name if not player.last_name.is_empty() else ("%s %s" % [player.first_name, player.last_name]).strip_edges()
	player.positions = _positions_from_field(position_field.text)
	player.bats = bats_field.text.strip_edges()
	if player.bats.is_empty():
		player.bats = "Unknown"
	player.throws_hand = throws_field.text.strip_edges()
	if player.throws_hand.is_empty():
		player.throws_hand = "Unknown"
	player.notes = notes_field.text.strip_edges()
	SaveManagerScript.save_project(repository)
	_selected_player_id = player.id
	_editing_player_id = ""
	_refresh_game_context()
	event_summary_panel.set_selected_event_summary(_summary_for_player(player))

func _positions_from_field(value: String) -> Array[String]:
	var positions: Array[String] = []
	for raw_position in value.split(",", false):
		var position = raw_position.strip_edges()
		if not position.is_empty():
			positions.append(position)
	return positions

func _has_duplicate_jersey_number_for_other_player(team_id: String, jersey_number: String, ignored_player_id: String = "") -> bool:
	var normalized_jersey = jersey_number.strip_edges()
	if repository == null or team_id.is_empty() or normalized_jersey.is_empty():
		return false
	for player in repository.players:
		if player.id != ignored_player_id and player.team_id == team_id and player.jersey_number.strip_edges() == normalized_jersey:
			return true
	return false

func _summary_for_player(player: Player) -> String:
	var parts: Array[String] = ["Selected roster player: #%s %s" % [player.jersey_number if not player.jersey_number.is_empty() else "--", player.display_name if not player.display_name.is_empty() else player.id]]
	if not player.positions.is_empty():
		parts.append("Positions: %s" % ", ".join(player.positions))
	parts.append("Bats: %s | Throws: %s" % [player.bats, player.throws_hand])
	parts.append("Click Edit to update this player.")
	return "\n".join(parts)

func _team_name(team: Team) -> String:
	return team.name if team != null and not team.name.is_empty() else "Unknown Team"

func _starting_pitcher_ids() -> Dictionary:
	if current_game == null:
		return {}
	return {"home": current_game.home_starting_pitcher_id, "away": current_game.away_starting_pitcher_id}

func _starting_pitchers_missing() -> bool:
	return current_game != null and (current_game.home_starting_pitcher_id.strip_edges().is_empty() or current_game.away_starting_pitcher_id.strip_edges().is_empty())

func _active_pitcher_id_for_defense_side(defense_team_id: String, events: Array) -> String:
	if current_game == null:
		return ""
	var state = _scoreboard_state_for_events(events)
	if defense_team_id == current_game.home_team_id:
		return str(state.get("home_pitcher_id", current_game.home_starting_pitcher_id))
	if defense_team_id == current_game.away_team_id:
		return str(state.get("away_pitcher_id", current_game.away_starting_pitcher_id))
	return ""

func _update_active_pitcher_panel(event_id: String = "") -> void:
	var state = _scoreboard_state_for_event(event_id) if not event_id.strip_edges().is_empty() else _scoreboard_state_for_events(_events_for_current_game())
	active_pitcher_panel.set_pitchers(str(state.get("home_pitcher_name", "")), str(state.get("away_pitcher_name", "")))

func _on_select_starting_pitchers_requested() -> void:
	_open_starting_pitcher_dialog(false)

func _build_starting_pitcher_dialog() -> void:
	starting_pitcher_dialog = AcceptDialog.new()
	starting_pitcher_dialog.title = "Select Starting Pitchers"
	starting_pitcher_dialog.min_size = Vector2i(520, 300)
	starting_pitcher_dialog.confirmed.connect(_on_starting_pitchers_confirmed)
	add_child(starting_pitcher_dialog)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	starting_pitcher_dialog.add_child(box)
	var help = Label.new()
	help.text = "Choose one player from each roster to act as the starting pitchers for this game."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	GameEntryStyle.style_body_label(help)
	home_starting_pitcher_selector = _add_pitcher_selector_row(box, "Home Pitcher")
	away_starting_pitcher_selector = _add_pitcher_selector_row(box, "Away Pitcher")
	starting_pitcher_warning_label = Label.new()
	starting_pitcher_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(starting_pitcher_warning_label)
	GameEntryStyle.style_body_label(starting_pitcher_warning_label)

func _add_pitcher_selector_row(parent: VBoxContainer, label_text: String) -> OptionButton:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label = Label.new()
	label.custom_minimum_size.x = 120
	label.text = label_text
	row.add_child(label)
	var selector = OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(selector)
	selector.item_selected.connect(func(_index: int) -> void: _refresh_starting_pitcher_warning())
	return selector

func _open_starting_pitcher_dialog(required: bool = false) -> void:
	_populate_starting_pitcher_selector(home_starting_pitcher_selector, current_game.home_team_id, current_game.home_starting_pitcher_id)
	_populate_starting_pitcher_selector(away_starting_pitcher_selector, current_game.away_team_id, current_game.away_starting_pitcher_id)
	_refresh_starting_pitcher_warning()
	starting_pitcher_dialog.title = "Select Starting Pitchers" if not required else "Select Starting Pitchers Required"
	starting_pitcher_dialog.popup_centered(Vector2i(520, 300))

func _populate_starting_pitcher_selector(selector: OptionButton, team_id: String, selected_player_id: String) -> void:
	selector.clear()
	selector.add_item("-- Select pitcher --")
	selector.set_item_metadata(0, "")
	for player in _players_for_team(team_id):
		selector.add_item("#%s %s" % [player.jersey_number if not player.jersey_number.is_empty() else "--", player.display_name])
		selector.set_item_metadata(selector.item_count - 1, player.id)
	for index in range(selector.item_count):
		if str(selector.get_item_metadata(index)) == selected_player_id:
			selector.select(index)
			return
	selector.select(0)

func _refresh_starting_pitcher_warning() -> void:
	if starting_pitcher_warning_label == null or current_game == null:
		return
	var selected_home = _selected_option_meta(home_starting_pitcher_selector)
	var selected_away = _selected_option_meta(away_starting_pitcher_selector)
	starting_pitcher_dialog.get_ok_button().disabled = selected_home.is_empty() or selected_away.is_empty()
	var changed_home = selected_home != current_game.home_starting_pitcher_id
	var changed_away = selected_away != current_game.away_starting_pitcher_id
	var impacted = _starting_pitcher_impacted_events(changed_home, changed_away)
	if _events_have_more_than_one_inning() and not impacted.is_empty():
		starting_pitcher_warning_label.text = "Warning: changing starting pitchers will update pitcher_id on %d event(s) before an official pitching change: %s" % [impacted.size(), ", ".join(impacted)]
	else:
		starting_pitcher_warning_label.text = ""

func _on_starting_pitchers_confirmed() -> void:
	if _selected_option_meta(home_starting_pitcher_selector).is_empty() or _selected_option_meta(away_starting_pitcher_selector).is_empty():
		_open_starting_pitcher_dialog(true)
		return
	var old_home = current_game.home_starting_pitcher_id
	var old_away = current_game.away_starting_pitcher_id
	current_game.home_starting_pitcher_id = _selected_option_meta(home_starting_pitcher_selector)
	current_game.away_starting_pitcher_id = _selected_option_meta(away_starting_pitcher_selector)
	_apply_starting_pitcher_to_early_events("home", old_home, current_game.home_starting_pitcher_id)
	_apply_starting_pitcher_to_early_events("away", old_away, current_game.away_starting_pitcher_id)
	SaveManagerScript.save_project(repository)
	_refresh_game_context()

func _apply_starting_pitcher_to_early_events(side: String, old_id: String, new_id: String) -> void:
	if old_id == new_id or new_id.strip_edges().is_empty():
		return
	for event in _events_before_first_pitching_change(side):
		if old_id.strip_edges().is_empty() or event.pitcher_id == old_id:
			event.pitcher_id = new_id

func _events_before_first_pitching_change(side: String) -> Array:
	var output: Array = []
	for event in _events_for_current_game():
		var event_side = "home" if event.half_inning == "top" else "away"
		if event_side != side:
			continue
		if _normalize_event_type(str(event.details.get("event_type", event.event_type))) == "pitching_change":
			break
		output.append(event)
	return output

func _starting_pitcher_impacted_events(changed_home: bool, changed_away: bool) -> Array[String]:
	var impacted: Array[String] = []
	if changed_home:
		for event in _events_before_first_pitching_change("home"):
			impacted.append("#%d %s" % [event.sequence_number, event.event_type])
	if changed_away:
		for event in _events_before_first_pitching_change("away"):
			impacted.append("#%d %s" % [event.sequence_number, event.event_type])
	return impacted

func _events_have_more_than_one_inning() -> bool:
	for event in _events_for_current_game():
		if event.inning > 1:
			return true
	return false

func _selected_option_meta(selector: OptionButton) -> String:
	return str(selector.get_item_metadata(selector.selected)) if selector != null and selector.selected >= 0 else ""
