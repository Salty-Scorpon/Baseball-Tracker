extends PanelContainer
class_name SkinnyEventHistoryPanel

signal event_selected(event_id: String)

const GameEntryStyle = preload("res://modes/game_entry/GameEntryStyle.gd")

@onready var title_label: Label = %EventHistoryLabel
@onready var rows_box: VBoxContainer = %EventHistoryRows
@onready var empty_label: Label = %EmptyHistoryLabel

var _events: Array = []
var _context: Dictionary = {}
var _selected_event_id := ""
var _buttons_by_event_id: Dictionary = {}

func _ready() -> void:
	_apply_style()
	_render_rows()

func set_events(events: Array, context: Dictionary = {}) -> void:
	_events = events.duplicate(true)
	_context = context.duplicate(true)
	_render_rows()
	if not _selected_event_id.is_empty():
		select_event(_selected_event_id)

func select_event(event_id: String) -> void:
	if event_id.is_empty() or not _buttons_by_event_id.has(event_id):
		return
	if _selected_event_id == event_id:
		_update_selection()
		return
	_selected_event_id = event_id
	_update_selection()
	event_selected.emit(event_id)

func clear() -> void:
	_events.clear()
	_context.clear()
	_selected_event_id = ""
	_render_rows()

func _render_rows() -> void:
	_buttons_by_event_id.clear()
	for child in rows_box.get_children():
		child.queue_free()
	if not _selected_event_id.is_empty() and not _events.any(func(raw_event: Variant) -> bool: return _event_id(_event_to_dictionary(raw_event)) == _selected_event_id):
		_selected_event_id = ""
	empty_label.visible = _events.is_empty()
	for raw_event in _events:
		var event := _event_to_dictionary(raw_event)
		var event_id := _event_id(event)
		if event_id.is_empty():
			continue
		var button := _make_event_row(event)
		rows_box.add_child(button)
		_buttons_by_event_id[event_id] = button
	_update_selection()

func _make_event_row(event: Dictionary) -> Button:
	var event_id := _event_id(event)
	var button := Button.new()
	button.text = _compact_row_text(event)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = _compact_tooltip(event)
	button.pressed.connect(func() -> void: select_event(event_id))
	GameEntryStyle.style_button(button)
	return button

func _compact_row_text(event: Dictionary) -> String:
	var parts: Array[String] = ["#%s" % _sequence_label(event), _half_inning_label(event), _event_code(event)]
	var player_name := _primary_player_name(event)
	if not player_name.is_empty():
		parts.append(player_name)
	var runs_marker := _runs_marker(event)
	if not runs_marker.is_empty():
		parts.append(runs_marker)
	if _has_manual_override(event):
		parts.append("⚠")
	return " ".join(parts)

func _compact_tooltip(event: Dictionary) -> String:
	var tooltip := _compact_row_text(event)
	var notes := str(event.get("notes", "")).strip_edges()
	if not notes.is_empty():
		tooltip += "\n%s" % notes
	return tooltip

func _update_selection() -> void:
	for event_id in _buttons_by_event_id.keys():
		GameEntryStyle.set_button_selected(_buttons_by_event_id[event_id], event_id == _selected_event_id)

func _apply_style() -> void:
	GameEntryStyle.style_content_panel(self)
	GameEntryStyle.style_title_label(title_label)
	GameEntryStyle.style_body_label(empty_label)

func _event_to_dictionary(raw_event: Variant) -> Dictionary:
	if raw_event is Dictionary:
		return Dictionary(raw_event).duplicate(true)
	if raw_event != null and raw_event.has_method("to_dict"):
		return raw_event.to_dict()
	return {}

func _event_id(event: Dictionary) -> String:
	return str(event.get("id", event.get("event_id", ""))).strip_edges()

func _sequence_label(event: Dictionary) -> String:
	return "%02d" % int(event.get("sequence", event.get("sequence_number", 0)))

func _half_inning_label(event: Dictionary) -> String:
	var half := str(event.get("half", event.get("half_inning", ""))).strip_edges().to_lower()
	var prefix := "T" if half == "top" else "B" if half == "bottom" else "?"
	var inning := int(event.get("inning", 0))
	return "%s%d" % [prefix, inning]

func _event_code(event: Dictionary) -> String:
	var raw_code := str(event.get("event_code", event.get("code", ""))).strip_edges()
	if not raw_code.is_empty():
		return raw_code.to_upper()
	var event_type := str(event.get("event_type", event.get("result", ""))).strip_edges().to_lower()
	var code_map := {
		"single": "1B", "double": "2B", "triple": "3B", "home_run": "HR", "homerun": "HR", "walk": "BB", "intentional_walk": "IBB", "hit_by_pitch": "HBP", "strikeout": "K", "strikeout_swinging": "K", "strikeout_looking": "K", "groundout": "GO", "flyout": "FO", "lineout": "LO", "popout": "PO", "reached_on_error": "E", "error": "E", "fielders_choice": "FC", "fielder_choice": "FC", "sacrifice_bunt": "SAC", "sacrifice_fly": "SF", "stolen_base": "SB", "caught_stealing": "CS", "wild_pitch": "WP", "passed_ball": "PB", "balk": "BK", "double_play": "DP", "triple_play": "TP", "substitution": "SUB", "pitching_change": "PCH", "manual_correction": "MAN"
	}
	return str(code_map.get(event_type, event_type.to_upper())) if not event_type.is_empty() else "EVT"

func _primary_player_name(event: Dictionary) -> String:
	for key in ["batter_name", "player_name", "primary_player_name"]:
		var direct_name := str(event.get(key, "")).strip_edges()
		if not direct_name.is_empty():
			return direct_name
	for key in ["batter_id", "player_id", "runner_id", "pitcher_id"]:
		var player_id := str(event.get(key, "")).strip_edges()
		var label := _player_label(player_id)
		if not label.is_empty():
			return label
	return ""

func _player_label(player_id: String) -> String:
	if player_id.is_empty():
		return ""
	var players := Dictionary(_context.get("players_by_id", {}))
	if players.has(player_id):
		var value = players[player_id]
		if value is Dictionary:
			return str(value.get("display_name", value.get("name", player_id))).strip_edges()
		if value != null and value.has_method("get"):
			var display_name = value.get("display_name")
			if display_name != null and not str(display_name).strip_edges().is_empty():
				return str(display_name).strip_edges()
	return player_id

func _runs_marker(event: Dictionary) -> String:
	var runs := 0
	var runs_scored = event.get("runs_scored", [])
	if runs_scored is Array:
		runs = runs_scored.size()
	elif runs_scored is int or runs_scored is float:
		runs = int(runs_scored)
	else:
		runs = int(event.get("runs", 0))
	return "+%dR" % runs if runs > 0 else ""

func _has_manual_override(event: Dictionary) -> bool:
	var overrides := Dictionary(event.get("manual_overrides", {})) if event.get("manual_overrides", {}) is Dictionary else {}
	return bool(event.get("manual_override", false)) or not overrides.is_empty()
