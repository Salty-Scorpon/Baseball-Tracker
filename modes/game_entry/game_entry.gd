extends Control

signal navigate_requested(screen_name: StringName)
signal event_key_selected(event_type: String)
signal add_player_requested

const GameEntryStyle = preload("res://modes/game_entry/GameEntryStyle.gd")

@onready var background: ColorRect = %Background
@onready var left_dock: PanelContainer = %LeftDock
@onready var center_dock: PanelContainer = %CenterDock
@onready var right_dock: PanelContainer = %RightDock
@onready var event_key_panel: EventKeyPanel = %EventKeyPanel
@onready var team_quick_roster_panel: PanelContainer = %TeamQuickRosterPanel
@onready var workspace_panel: PanelContainer = %WorkspacePanel
@onready var event_summary_panel: PanelContainer = %EventSummaryPanel
@onready var skinny_event_history_panel: PanelContainer = %SkinnyEventHistoryPanel
@onready var compact_scoreboard_panel: PanelContainer = %CompactScoreboardPanel
@onready var roster_label: Label = %RosterLabel
@onready var workspace_label: Label = %WorkspaceLabel
@onready var event_summary_label: Label = %EventSummaryLabel
@onready var event_history_label: Label = %EventHistoryLabel
@onready var scoreboard_label: Label = %ScoreboardLabel
@onready var roster_placeholder: Label = %RosterPlaceholder
@onready var workspace_placeholder: Label = %WorkspacePlaceholder
@onready var event_history_placeholder: Label = %EventHistoryPlaceholder
@onready var scoreboard_placeholder: Label = %ScoreboardPlaceholder
@onready var add_player_button: Button = %AddPlayerButton
@onready var shell_status_label: Label = %ShellStatusLabel


func _ready() -> void:
	_apply_style()
	event_key_panel.event_type_selected.connect(_on_event_key_pressed)
	add_player_button.pressed.connect(_on_add_player_pressed)

func _apply_style() -> void:
	GameEntryStyle.apply_shell_style(
		self,
		background,
		[left_dock, center_dock, right_dock],
		[event_key_panel, team_quick_roster_panel, workspace_panel, event_summary_panel, skinny_event_history_panel, compact_scoreboard_panel],
		[roster_label, workspace_label, event_summary_label, event_history_label, scoreboard_label],
		[roster_placeholder, workspace_placeholder, shell_status_label, event_history_placeholder, scoreboard_placeholder],
		[add_player_button]
	)

func _on_event_key_pressed(event_type: String) -> void:
	shell_status_label.text = "Selected event key: %s (placeholder shell only)." % event_type.replace("_", " ").capitalize()
	event_key_selected.emit(event_type)

func _on_add_player_pressed() -> void:
	shell_status_label.text = "Add Player requested (placeholder shell only)."
	add_player_requested.emit()
