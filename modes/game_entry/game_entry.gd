extends Control

signal navigate_requested(screen_name: StringName)
signal event_key_selected(event_type: String)
signal add_player_requested

const GameEntryStyle = preload("res://modes/game_entry/GameEntryStyle.gd")

const EVENT_KEYS: Array[Dictionary] = [
	{"label": "1B", "event_type": "single", "implemented": true},
	{"label": "2B", "event_type": "double", "implemented": true},
	{"label": "3B", "event_type": "triple", "implemented": true},
	{"label": "HR", "event_type": "home_run", "implemented": true},
	{"label": "BB", "event_type": "walk", "implemented": true},
	{"label": "HBP", "event_type": "hit_by_pitch", "implemented": true},
	{"label": "K", "event_type": "strikeout", "implemented": true},
	{"label": "GO", "event_type": "groundout", "implemented": true},
	{"label": "FO", "event_type": "flyout", "implemented": true},
	{"label": "E", "event_type": "reached_on_error", "implemented": true},
	{"label": "FC", "event_type": "fielders_choice", "implemented": true},
	{"label": "SAC", "event_type": "sacrifice", "implemented": false},
	{"label": "SB", "event_type": "stolen_base", "implemented": true},
	{"label": "CS", "event_type": "caught_stealing", "implemented": false},
	{"label": "WP", "event_type": "wild_pitch", "implemented": false},
	{"label": "PB", "event_type": "passed_ball", "implemented": false},
	{"label": "BK", "event_type": "balk", "implemented": false},
	{"label": "DP", "event_type": "double_play", "implemented": true},
	{"label": "TP", "event_type": "triple_play", "implemented": true},
	{"label": "SUB", "event_type": "substitution", "implemented": true},
	{"label": "PCH", "event_type": "pitching_change", "implemented": true},
	{"label": "MAN", "event_type": "manual_correction", "implemented": true},
]

@onready var background: ColorRect = %Background
@onready var left_dock: PanelContainer = %LeftDock
@onready var center_dock: PanelContainer = %CenterDock
@onready var right_dock: PanelContainer = %RightDock
@onready var event_key_panel: PanelContainer = %EventKeyPanel
@onready var team_quick_roster_panel: PanelContainer = %TeamQuickRosterPanel
@onready var workspace_panel: PanelContainer = %WorkspacePanel
@onready var event_summary_panel: PanelContainer = %EventSummaryPanel
@onready var skinny_event_history_panel: PanelContainer = %SkinnyEventHistoryPanel
@onready var compact_scoreboard_panel: PanelContainer = %CompactScoreboardPanel
@onready var event_keys_label: Label = %EventKeysLabel
@onready var roster_label: Label = %RosterLabel
@onready var workspace_label: Label = %WorkspaceLabel
@onready var event_summary_label: Label = %EventSummaryLabel
@onready var event_history_label: Label = %EventHistoryLabel
@onready var scoreboard_label: Label = %ScoreboardLabel
@onready var roster_placeholder: Label = %RosterPlaceholder
@onready var workspace_placeholder: Label = %WorkspacePlaceholder
@onready var event_history_placeholder: Label = %EventHistoryPlaceholder
@onready var scoreboard_placeholder: Label = %ScoreboardPlaceholder
@onready var event_buttons_grid: GridContainer = %EventButtonsGrid
@onready var add_player_button: Button = %AddPlayerButton
@onready var shell_status_label: Label = %ShellStatusLabel

var _event_buttons_by_type: Dictionary = {}
var _selected_event_type := ""

func _ready() -> void:
	_build_event_key_buttons()
	_apply_style()
	add_player_button.pressed.connect(_on_add_player_pressed)

func _build_event_key_buttons() -> void:
	_event_buttons_by_type.clear()
	for child in event_buttons_grid.get_children():
		child.queue_free()
	for event_config in EVENT_KEYS:
		var event_type := str(event_config["event_type"])
		var implemented := bool(event_config["implemented"])
		var button := Button.new()
		button.text = str(event_config["label"])
		button.custom_minimum_size = Vector2(72, 34)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not implemented
		button.tooltip_text = _event_key_tooltip(event_type, implemented)
		button.pressed.connect(func() -> void: _on_event_key_pressed(event_type))
		event_buttons_grid.add_child(button)
		_event_buttons_by_type[event_type] = button

func _apply_style() -> void:
	GameEntryStyle.apply_shell_style(
		self,
		background,
		[left_dock, center_dock, right_dock],
		[event_key_panel, team_quick_roster_panel, workspace_panel, event_summary_panel, skinny_event_history_panel, compact_scoreboard_panel],
		[event_keys_label, roster_label, workspace_label, event_summary_label, event_history_label, scoreboard_label],
		[roster_placeholder, workspace_placeholder, shell_status_label, event_history_placeholder, scoreboard_placeholder],
		_event_buttons_by_type.values() + [add_player_button]
	)

func _event_key_tooltip(event_type: String, implemented: bool) -> String:
	var label := event_type.replace("_", " ").capitalize()
	return label if implemented else "%s template not implemented yet" % label

func _on_event_key_pressed(event_type: String) -> void:
	_select_event_key(event_type)
	shell_status_label.text = "Selected event key: %s (placeholder shell only)." % event_type.replace("_", " ").capitalize()
	event_key_selected.emit(event_type)

func _select_event_key(event_type: String) -> void:
	if _selected_event_type == event_type:
		return
	if _event_buttons_by_type.has(_selected_event_type):
		GameEntryStyle.set_button_selected(_event_buttons_by_type[_selected_event_type], false)
	_selected_event_type = event_type
	if _event_buttons_by_type.has(_selected_event_type):
		GameEntryStyle.set_button_selected(_event_buttons_by_type[_selected_event_type], true)

func _on_add_player_pressed() -> void:
	shell_status_label.text = "Add Player requested (placeholder shell only)."
	add_player_requested.emit()
