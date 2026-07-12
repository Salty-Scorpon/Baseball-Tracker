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
@onready var team_quick_roster_panel: TeamQuickRosterPanel = %TeamQuickRosterPanel
@onready var workspace_panel: PanelContainer = %WorkspacePanel
@onready var event_summary_panel: PanelContainer = %EventSummaryPanel
@onready var skinny_event_history_panel: PanelContainer = %SkinnyEventHistoryPanel
@onready var compact_scoreboard_panel: PanelContainer = %CompactScoreboardPanel
@onready var workspace_label: Label = %WorkspaceLabel
@onready var event_summary_label: Label = %EventSummaryLabel
@onready var event_history_label: Label = %EventHistoryLabel
@onready var scoreboard_label: Label = %ScoreboardLabel
@onready var workspace_placeholder: Label = %WorkspacePlaceholder
@onready var event_history_placeholder: Label = %EventHistoryPlaceholder
@onready var scoreboard_placeholder: Label = %ScoreboardPlaceholder
@onready var shell_status_label: Label = %ShellStatusLabel


func _ready() -> void:
	_apply_style()
	event_key_panel.event_type_selected.connect(_on_event_key_pressed)
	team_quick_roster_panel.roster_team_tab_changed.connect(_on_roster_team_tab_changed)
	team_quick_roster_panel.player_selected.connect(_on_roster_player_selected)
	team_quick_roster_panel.add_player_requested.connect(_on_roster_add_player_requested)
	_load_demo_rosters()

func _apply_style() -> void:
	GameEntryStyle.apply_shell_style(
		self,
		background,
		[left_dock, center_dock, right_dock],
		[event_key_panel, team_quick_roster_panel, workspace_panel, event_summary_panel, skinny_event_history_panel, compact_scoreboard_panel],
		[workspace_label, event_summary_label, event_history_label, scoreboard_label],
		[workspace_placeholder, shell_status_label, event_history_placeholder, scoreboard_placeholder],
		[]
	)

func _on_event_key_pressed(event_type: String) -> void:
	shell_status_label.text = "Selected event key: %s (placeholder shell only)." % event_type.replace("_", " ").capitalize()
	event_key_selected.emit(event_type)

func _load_demo_rosters() -> void:
	team_quick_roster_panel.set_home_roster([
		{"id": "demo_home_1", "team_id": "demo_home", "jersey_number": "1", "display_name": "Kambe"},
		{"id": "demo_home_8", "team_id": "demo_home", "jersey_number": "8", "display_name": "Shibata"},
		{"id": "demo_home_6", "team_id": "demo_home", "jersey_number": "6", "display_name": "Shigemune Daiki"},
	])
	team_quick_roster_panel.set_away_roster([
		{"id": "demo_away_3", "team_id": "demo_away", "jersey_number": "3", "display_name": "Taiga Eto"},
		{"id": "demo_away_10", "team_id": "demo_away", "jersey_number": "10", "display_name": "Makiuchi"},
	])


func _on_roster_team_tab_changed(side: String) -> void:
	shell_status_label.text = "Showing %s quick roster." % side.capitalize()


func _on_roster_player_selected(player_id: String) -> void:
	shell_status_label.text = "Selected roster player: %s" % player_id


func _on_roster_add_player_requested(team_id: String) -> void:
	shell_status_label.text = "Add Player requested for team: %s" % team_id
	add_player_requested.emit()
