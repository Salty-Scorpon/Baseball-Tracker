extends PanelContainer
class_name TeamQuickRosterPanel

signal roster_team_tab_changed(side: String)
signal player_selected(player_id: String)
signal add_player_requested(team_id: String)

const GameEntryStyle = preload("res://modes/game_entry/GameEntryStyle.gd")
const SIDE_HOME := "home"
const SIDE_AWAY := "away"
const VALID_SIDES := [SIDE_HOME, SIDE_AWAY]

@onready var title_label: Label = %RosterTitleLabel
@onready var home_tab_button: Button = %HomeTabButton
@onready var away_tab_button: Button = %AwayTabButton
@onready var roster_rows: VBoxContainer = %RosterRows
@onready var empty_label: Label = %EmptyRosterLabel

var _selected_side := SIDE_HOME
var _home_roster: Array = []
var _away_roster: Array = []
var _home_team_id := "home"
var _away_team_id := "away"


func set_team_ids(home_team_id: String, away_team_id: String) -> void:
	_home_team_id = home_team_id
	_away_team_id = away_team_id


func _ready() -> void:
	home_tab_button.pressed.connect(func() -> void: set_selected_side(SIDE_HOME))
	away_tab_button.pressed.connect(func() -> void: set_selected_side(SIDE_AWAY))
	_apply_style()
	_refresh_tabs()
	_refresh_roster_rows()


func set_home_roster(players: Array) -> void:
	_home_roster = players.duplicate()
	_home_team_id = _team_id_from_roster(_home_roster, _home_team_id)
	if _selected_side == SIDE_HOME:
		_refresh_roster_rows()


func set_away_roster(players: Array) -> void:
	_away_roster = players.duplicate()
	_away_team_id = _team_id_from_roster(_away_roster, _away_team_id)
	if _selected_side == SIDE_AWAY:
		_refresh_roster_rows()


func set_selected_side(side: String) -> void:
	var normalized_side := side.to_lower()
	if not VALID_SIDES.has(normalized_side):
		push_warning("Unsupported roster side '%s'. Expected 'home' or 'away'." % side)
		return
	if _selected_side == normalized_side:
		return
	_selected_side = normalized_side
	_refresh_tabs()
	_refresh_roster_rows()
	roster_team_tab_changed.emit(_selected_side)


func get_selected_side() -> String:
	return _selected_side


func get_selected_team_id() -> String:
	return _home_team_id if _selected_side == SIDE_HOME else _away_team_id


func _current_roster() -> Array:
	return _home_roster if _selected_side == SIDE_HOME else _away_roster


func _refresh_tabs() -> void:
	GameEntryStyle.set_button_selected(home_tab_button, _selected_side == SIDE_HOME)
	GameEntryStyle.set_button_selected(away_tab_button, _selected_side == SIDE_AWAY)


func request_add_player() -> void:
	add_player_requested.emit(get_selected_team_id())


func can_add_player_to_selected_team() -> bool:
	return not get_selected_team_id().strip_edges().is_empty()


func _refresh_roster_rows() -> void:
	for child in roster_rows.get_children():
		child.queue_free()
	var players := _current_roster()
	empty_label.visible = players.is_empty()
	for player in players:
		roster_rows.add_child(_build_player_row(player))


func _build_player_row(player: Variant) -> Button:
	var player_id := _player_field(player, "id", "")
	var jersey_number := _player_field(player, "jersey_number", "--")
	var display_name := _player_display_name(player)
	var button := Button.new()
	button.text = "#%s %s" % [jersey_number, display_name]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "Select %s" % display_name
	button.pressed.connect(func() -> void: player_selected.emit(player_id))
	GameEntryStyle.style_button(button)
	return button


func _player_display_name(player: Variant) -> String:
	var display_name := _player_field(player, "display_name", "")
	if not display_name.is_empty():
		return display_name
	var first_name := _player_field(player, "first_name", "")
	var last_name := _player_field(player, "last_name", "")
	var combined_name := "%s %s" % [first_name, last_name]
	combined_name = combined_name.strip_edges()
	return combined_name if not combined_name.is_empty() else "Unnamed Player"


func _player_field(player: Variant, field_name: String, default_value: String) -> String:
	if player is Dictionary:
		return str(player.get(field_name, default_value))
	if player is Object:
		var value = player.get(field_name)
		return default_value if value == null else str(value)
	return default_value


func _team_id_from_roster(players: Array, fallback: String) -> String:
	for player in players:
		var team_id := _player_field(player, "team_id", "")
		if not team_id.is_empty():
			return team_id
	return fallback


func _apply_style() -> void:
	GameEntryStyle.style_content_panel(self)
	GameEntryStyle.style_title_label(title_label)
	GameEntryStyle.style_body_label(empty_label)
	GameEntryStyle.style_button(home_tab_button)
	GameEntryStyle.style_button(away_tab_button)
