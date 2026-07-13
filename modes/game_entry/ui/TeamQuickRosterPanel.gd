extends PanelContainer
class_name TeamQuickRosterPanel

signal roster_team_tab_changed(side: String)
signal player_selected(player_id: String)
signal add_player_requested(team_id: String)

const GameEntryStyle = preload("res://modes/game_entry/GameEntryStyle.gd")
const SIDE_HOME = "home"
const SIDE_AWAY = "away"
const VALID_SIDES = [SIDE_HOME, SIDE_AWAY]

@onready var title_label: Label = %RosterTitleLabel
@onready var home_tab_button: Button = %HomeTabButton
@onready var away_tab_button: Button = %AwayTabButton
@onready var roster_rows: VBoxContainer = %RosterRows
@onready var empty_label: Label = %EmptyRosterLabel

var _selected_side = SIDE_HOME
var _home_roster: Array = []
var _away_roster: Array = []
var _home_team_id = "home"
var _away_team_id = "away"
var _selected_player_id = ""
var _buttons_by_player_id: Dictionary = {}
var _lineups_by_side: Dictionary = {SIDE_HOME: [], SIDE_AWAY: []}
var _active_batter_ids_by_side: Dictionary = {SIDE_HOME: "", SIDE_AWAY: ""}


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
	var normalized_side = side.to_lower()
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
	return get_roster_for_side(_selected_side)

func get_roster_for_side(side: String) -> Array:
	return _home_roster if side == SIDE_HOME else _away_roster

func get_lineup_for_side(side: String) -> Array:
	return Array(_lineups_by_side.get(side, [])).duplicate()

func get_lineup_for_team_id(team_id: String) -> Array:
	if team_id == _home_team_id:
		return get_lineup_for_side(SIDE_HOME)
	if team_id == _away_team_id:
		return get_lineup_for_side(SIDE_AWAY)
	return []

func set_lineup_for_side(side: String, lineup: Array) -> void:
	var normalized_side = side.to_lower()
	if not VALID_SIDES.has(normalized_side):
		return
	var trimmed: Array[String] = []
	for index in range(9):
		trimmed.append(str(lineup[index]) if index < lineup.size() else "")
	_lineups_by_side[normalized_side] = trimmed
	if _selected_side == normalized_side:
		_refresh_roster_rows()

func set_active_batter_ids(home_player_id: String, away_player_id: String) -> void:
	_active_batter_ids_by_side[SIDE_HOME] = home_player_id
	_active_batter_ids_by_side[SIDE_AWAY] = away_player_id
	_refresh_roster_rows()


func _refresh_tabs() -> void:
	GameEntryStyle.set_button_selected(home_tab_button, _selected_side == SIDE_HOME)
	GameEntryStyle.set_button_selected(away_tab_button, _selected_side == SIDE_AWAY)


func request_add_player() -> void:
	add_player_requested.emit(get_selected_team_id())


func can_add_player_to_selected_team() -> bool:
	return not get_selected_team_id().strip_edges().is_empty()


func _refresh_roster_rows() -> void:
	_buttons_by_player_id.clear()
	for child in roster_rows.get_children():
		child.queue_free()
	var players = _current_roster()
	if not _selected_player_id.is_empty() and not players.any(func(player: Variant) -> bool: return _player_field(player, "id", "") == _selected_player_id):
		_selected_player_id = ""
	empty_label.visible = players.is_empty()
	var player_by_id = {}
	for player in players:
		player_by_id[_player_field(player, "id", "")] = player
	var lineup_ids = _filled_lineup_ids_for_selected_side()
	if not lineup_ids.is_empty():
		_add_section_label("Batting Lineup")
		for lineup_index in range(lineup_ids.size()):
			var player_id = lineup_ids[lineup_index]
			if player_by_id.has(player_id):
				_add_player_row(player_by_id[player_id], lineup_index + 1)
		_add_section_label("Bench / Roster")
	for player in players:
		var player_id = _player_field(player, "id", "")
		if lineup_ids.has(player_id):
			continue
		_add_player_row(player, 0)
	_update_player_selection()


func clear_selection() -> void:
	_selected_player_id = ""
	_update_player_selection()


func _add_player_row(player: Variant, lineup_spot: int = 0) -> void:
	var row = _build_player_row(player, lineup_spot)
	roster_rows.add_child(row)
	var player_id = _player_field(player, "id", "")
	if not player_id.is_empty():
		_buttons_by_player_id[player_id] = row

func _add_section_label(text: String) -> void:
	var label = Label.new()
	label.text = text
	GameEntryStyle.style_body_label(label)
	roster_rows.add_child(label)

func _filled_lineup_ids_for_selected_side() -> Array[String]:
	var output: Array[String] = []
	for player_id in Array(_lineups_by_side.get(_selected_side, [])):
		var normalized_id = str(player_id).strip_edges()
		if not normalized_id.is_empty():
			output.append(normalized_id)
	return output

func _build_player_row(player: Variant, lineup_spot: int = 0) -> Button:
	var player_id = _player_field(player, "id", "")
	var jersey_number = _player_field(player, "jersey_number", "--")
	var display_name = _player_display_name(player)
	var button = Button.new()
	var active_marker = "● " if player_id == str(_active_batter_ids_by_side.get(_selected_side, "")) else "  "
	var lineup_prefix = "%d. " % lineup_spot if lineup_spot > 0 else ""
	button.text = "%s%s#%s %s" % [active_marker, lineup_prefix, jersey_number, display_name]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "Select %s" % display_name
	button.pressed.connect(func() -> void: _select_player(player_id))
	GameEntryStyle.style_button(button)
	if active_marker.strip_edges() == "●":
		button.add_theme_color_override("font_color", Color("#57d163"))
		button.add_theme_color_override("font_hover_color", Color("#57d163"))
		button.add_theme_color_override("font_pressed_color", Color("#57d163"))
	return button


func _select_player(player_id: String) -> void:
	if player_id.strip_edges().is_empty():
		return
	_selected_player_id = player_id
	_update_player_selection()
	player_selected.emit(player_id)


func _update_player_selection() -> void:
	for player_id in _buttons_by_player_id.keys():
		GameEntryStyle.set_button_selected(_buttons_by_player_id[player_id], player_id == _selected_player_id)


func _player_display_name(player: Variant) -> String:
	var display_name = _player_field(player, "display_name", "")
	if not display_name.is_empty():
		return display_name
	var first_name = _player_field(player, "first_name", "")
	var last_name = _player_field(player, "last_name", "")
	var combined_name = "%s %s" % [first_name, last_name]
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
		var team_id = _player_field(player, "team_id", "")
		if not team_id.is_empty():
			return team_id
	return fallback


func _apply_style() -> void:
	GameEntryStyle.style_content_panel(self)
	GameEntryStyle.style_title_label(title_label)
	GameEntryStyle.style_body_label(empty_label)
	GameEntryStyle.style_button(home_tab_button)
	GameEntryStyle.style_button(away_tab_button)
