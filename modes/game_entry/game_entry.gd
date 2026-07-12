extends Control

signal navigate_requested(screen_name: StringName)
signal event_key_selected(event_type: String)
signal add_player_requested(team_id: String)

const GameEntryStyle = preload("res://modes/game_entry/GameEntryStyle.gd")
const SaveManagerScript = preload("res://data/saving/save_manager.gd")
const SampleDataFactoryScript = preload("res://data/sample_data_factory.gd")

@onready var background: ColorRect = %Background
@onready var left_dock: PanelContainer = %LeftDock
@onready var center_dock: PanelContainer = %CenterDock
@onready var right_dock: PanelContainer = %RightDock
@onready var event_key_panel: EventKeyPanel = %EventKeyPanel
@onready var team_quick_roster_panel: TeamQuickRosterPanel = %TeamQuickRosterPanel
@onready var add_player_button: Button = %AddPlayerButton
@onready var workspace_panel: WorkspacePanel = %WorkspacePanel
@onready var event_summary_panel: PanelContainer = %EventSummaryPanel
@onready var skinny_event_history_panel: PanelContainer = %SkinnyEventHistoryPanel
@onready var compact_scoreboard_panel: PanelContainer = %CompactScoreboardPanel
@onready var workspace_label: Label = %WorkspaceTitleLabel
@onready var event_summary_label: Label = %EventSummaryLabel
@onready var event_history_label: Label = %EventHistoryLabel
@onready var scoreboard_label: Label = %ScoreboardLabel
@onready var workspace_placeholder: Label = %WorkspaceContextLabel
@onready var event_history_placeholder: Label = %EventHistoryPlaceholder
@onready var scoreboard_placeholder: Label = %ScoreboardPlaceholder
@onready var shell_status_label: Label = %ShellStatusLabel

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

func _ready() -> void:
	_apply_style()
	_build_add_player_dialog()
	event_key_panel.event_type_selected.connect(_on_event_key_pressed)
	workspace_panel.event_payload_changed.connect(_on_workspace_event_payload_changed)
	workspace_panel.event_selected.connect(_on_workspace_event_selected)
	workspace_panel.event_edit_requested.connect(_on_workspace_event_edit_requested)
	workspace_panel.event_creation_cancel_requested.connect(_on_workspace_event_creation_cancel_requested)
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
		[event_key_panel, team_quick_roster_panel, workspace_panel, event_summary_panel, skinny_event_history_panel, compact_scoreboard_panel],
		[workspace_label, event_summary_label, event_history_label, scoreboard_label],
		[workspace_placeholder, shell_status_label, event_history_placeholder, scoreboard_placeholder],
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
		shell_status_label.text = "No game is loaded. Add Player is disabled until a game has home and away teams."
		return
	team_quick_roster_panel.set_team_ids(current_game.home_team_id, current_game.away_team_id)
	team_quick_roster_panel.set_home_roster(_players_for_team(current_game.home_team_id))
	team_quick_roster_panel.set_away_roster(_players_for_team(current_game.away_team_id))
	_update_add_player_button_state()
	var home_team: Team = repository.find_entity_by_id(current_game.home_team_id, "teams")
	var away_team: Team = repository.find_entity_by_id(current_game.away_team_id, "teams")
	workspace_panel.set_events(_events_for_current_game(), _event_log_context())
	scoreboard_placeholder.text = "Game: %s vs %s\nStatus: %s" % [_team_name(away_team), _team_name(home_team), current_game.status]

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
	workspace_panel.show_create_event_mode(event_type, _build_workspace_game_context())
	shell_status_label.text = "Drafting event payload for: %s. Confirm/commit will be coordinated by GameEntryMode later." % event_type.replace("_", " ").capitalize()
	event_key_selected.emit(event_type)

func _on_workspace_event_payload_changed(payload: Dictionary) -> void:
	shell_status_label.text = "Workspace payload changed for %s mode." % str(payload.get("mode", workspace_panel.get_current_mode())).replace("_", " ")

func _on_workspace_event_selected(event_id: String) -> void:
	shell_status_label.text = "Selected event %s in the narrative event log." % event_id

func _on_workspace_event_edit_requested(event_id: String) -> void:
	workspace_panel.show_edit_event_mode(event_id, {"event_type": "groundout", "notes": "Placeholder event data."}, _build_workspace_game_context())
	shell_status_label.text = "Editing requested for event %s. Real event lookup will be wired to the event log later." % event_id

func _on_workspace_event_creation_cancel_requested() -> void:
	shell_status_label.text = "Event draft cancelled. Returned to event review."

func _build_workspace_game_context() -> Dictionary:
	if current_game == null:
		return {}
	return {
		"game_id": current_game.id,
		"inning": 1,
		"half": "Top",
		"outs": 0,
		"home_team_id": current_game.home_team_id,
		"away_team_id": current_game.away_team_id,
		"offense_team_id": current_game.away_team_id,
		"defense_team_id": current_game.home_team_id,
		"batter_id": "",
		"pitcher_id": "",
	}

func _on_roster_team_tab_changed(side: String) -> void:
	shell_status_label.text = "Showing %s quick roster. Add Player will target this tab's team." % side.capitalize()
	_update_add_player_button_state()

func _update_add_player_button_state() -> void:
	add_player_button.disabled = not team_quick_roster_panel.can_add_player_to_selected_team()
	add_player_button.text = "Add Player" if not add_player_button.disabled else "Add Player (select team)"

func _on_roster_player_selected(player_id: String) -> void:
	shell_status_label.text = "Selected roster player: %s" % player_id

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
		shell_status_label.text = "Could not create player for team %s." % _pending_add_team_id
		return
	SaveManagerScript.save_project(repository)
	_refresh_game_context()
	shell_status_label.text = "Added #%s %s to %s roster." % [player.jersey_number, player.display_name, team_quick_roster_panel.get_selected_side().capitalize()]

func _team_name(team: Team) -> String:
	return team.name if team != null and not team.name.is_empty() else "Unknown Team"
