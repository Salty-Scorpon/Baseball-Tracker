extends PanelContainer
class_name EventLogView

signal event_selected(event_id: String)
signal event_edit_requested(event_id: String)

const GameEntryStyle = preload("res://modes/game_entry/GameEntryStyle.gd")

@onready var scroll_container: ScrollContainer = %EventLogScroll
@onready var entries_box: VBoxContainer = %EventEntriesBox
@onready var empty_state_label: Label = %EmptyStateLabel

var _events: Array = []
var _context: Dictionary = {}
var _selected_event_id := ""
var _cards_by_event_id: Dictionary = {}

func _ready() -> void:
	_apply_style()
	_render_events()

func set_events(events: Array, context: Dictionary = {}) -> void:
	_events = events.duplicate(true)
	_context = context.duplicate(true)
	_render_events()
	if not _selected_event_id.is_empty():
		select_event(_selected_event_id)

func select_event(event_id: String) -> void:
	if event_id.is_empty() or not _cards_by_event_id.has(event_id):
		return
	if _selected_event_id == event_id:
		_update_card_selection()
		return
	_selected_event_id = event_id
	_update_card_selection()
	event_selected.emit(event_id)

func scroll_to_event(event_id: String) -> void:
	if not _cards_by_event_id.has(event_id):
		return
	select_event(event_id)
	await get_tree().process_frame
	var card: Control = _cards_by_event_id[event_id]
	var target_y := max(0, int(card.position.y - (scroll_container.size.y - card.size.y) * 0.5))
	scroll_container.set_deferred("scroll_vertical", target_y)

func clear() -> void:
	_events.clear()
	_selected_event_id = ""
	_context.clear()
	_render_events()

func _render_events() -> void:
	_cards_by_event_id.clear()
	for child in entries_box.get_children():
		if child != empty_state_label:
			child.queue_free()
	if not _selected_event_id.is_empty() and not _events.any(func(raw_event: Variant) -> bool: return _event_id(_event_to_dictionary(raw_event)) == _selected_event_id):
		_selected_event_id = ""
	empty_state_label.visible = _events.is_empty()
	var current_group := ""
	for raw_event in _events:
		var event := _event_to_dictionary(raw_event)
		var group := _group_key(event)
		if group != current_group:
			current_group = group
			entries_box.add_child(_make_group_header(event))
		var card := _make_event_card(event)
		entries_box.add_child(card)
		_cards_by_event_id[_event_id(event)] = card
	_update_card_selection()

func _make_group_header(event: Dictionary) -> Label:
	var label := Label.new()
	label.text = _group_title(event)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.95))
	label.custom_minimum_size = Vector2(0, 34)
	return label

func _make_event_card(event: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "EventCard_%s" % _event_id(event).replace("-", "_")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.gui_input.connect(func(input_event: InputEvent) -> void: _on_card_gui_input(input_event, _event_id(event)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var header := Label.new()
	header.text = _card_header(event)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(header)
	var summary := RichTextLabel.new()
	summary.bbcode_enabled = false
	summary.fit_content = true
	summary.scroll_active = false
	summary.text = _card_body(event)
	box.add_child(summary)
	var footer := Label.new()
	footer.text = _card_footer(event)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if footer.text.is_empty():
		footer.hide()
	box.add_child(footer)
	var edit_button := Button.new()
	edit_button.text = "Edit Event"
	edit_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	edit_button.pressed.connect(func() -> void: event_edit_requested.emit(_event_id(event)))
	box.add_child(edit_button)
	_style_card(card, false)
	GameEntryStyle.style_body_label(header)
	GameEntryStyle.style_body_label(footer)
	GameEntryStyle.style_button(edit_button)
	return card

func _on_card_gui_input(input_event: InputEvent, event_id: String) -> void:
	if input_event is InputEventMouseButton and input_event.pressed and input_event.button_index == MOUSE_BUTTON_LEFT:
		select_event(event_id)

func _update_card_selection() -> void:
	for event_id in _cards_by_event_id.keys():
		_style_card(_cards_by_event_id[event_id], event_id == _selected_event_id)

func _style_card(card: PanelContainer, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.23, 0.30) if selected else Color(0.115, 0.135, 0.17)
	style.border_color = Color(0.35, 0.62, 0.95) if selected else Color(0.22, 0.27, 0.34)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)

func _apply_style() -> void:
	GameEntryStyle.style_content_panel(self)
	GameEntryStyle.style_body_label(empty_state_label)

func _event_to_dictionary(raw_event: Variant) -> Dictionary:
	if raw_event is Dictionary:
		return Dictionary(raw_event).duplicate(true)
	if raw_event != null and raw_event.has_method("to_dict"):
		return raw_event.to_dict()
	return {}

func _card_header(event: Dictionary) -> String:
	return "#%s — %s, %s" % [_sequence_label(event), _group_title(event), _outs_label(int(event.get("outs_before", 0)))]

func _card_body(event: Dictionary) -> String:
	return EventSummaryFormatter.summarize(_decorate_event(event))

func _card_footer(event: Dictionary) -> String:
	var parts: Array[String] = []
	var notes := str(event.get("notes", "")).strip_edges()
	if _has_manual_override(event):
		parts.append("⚠ Manual scoring override")
	if not notes.is_empty():
		parts.append("Notes: %s" % notes)
	return "\n".join(parts)

func _decorate_event(event: Dictionary) -> Dictionary:
	var decorated := event.duplicate(true)
	for role in ["batter", "pitcher"]:
		var id_key := role + "_id"
		var name_key := role + "_name"
		if not decorated.has(name_key):
			decorated[name_key] = _player_label(str(decorated.get(id_key, "")))
	return decorated

func _player_label(player_id: String) -> String:
	var players := Dictionary(_context.get("players_by_id", {}))
	if players.has(player_id):
		var value = players[player_id]
		if value is Dictionary:
			return str(value.get("display_name", value.get("name", player_id)))
		if value != null and value.has_method("get"):
			var display_name = value.get("display_name")
			if display_name != null:
				return str(display_name)
	return player_id

func _event_id(event: Dictionary) -> String:
	return str(event.get("id", event.get("event_id", "event_%s" % _sequence_label(event))))

func _sequence_label(event: Dictionary) -> String:
	return "%02d" % int(event.get("sequence", event.get("sequence_number", 0)))

func _group_key(event: Dictionary) -> String:
	return "%d_%s" % [int(event.get("inning", 0)), str(event.get("half", event.get("half_inning", ""))).to_lower()]

func _group_title(event: Dictionary) -> String:
	var half := str(event.get("half", event.get("half_inning", ""))).to_lower()
	var inning := int(event.get("inning", 0))
	return "%s %s" % ["Top" if half == "top" else "Bottom" if half == "bottom" else "Half", _ordinal(inning)]

func _outs_label(outs: int) -> String:
	return "%d %s" % [outs, "out" if outs == 1 else "outs"]

func _ordinal(value: int) -> String:
	var suffix := "th"
	if value % 100 < 11 or value % 100 > 13:
		match value % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [value, suffix]

func _has_manual_override(event: Dictionary) -> bool:
	var overrides := Dictionary(event.get("manual_overrides", {})) if event.get("manual_overrides", {}) is Dictionary else {}
	return bool(event.get("manual_override", false)) or not overrides.is_empty()
