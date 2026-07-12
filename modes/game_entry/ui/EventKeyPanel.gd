extends PanelContainer
class_name EventKeyPanel

signal event_type_selected(event_type: String)

const GameEntryStyle = preload("res://modes/game_entry/GameEntryStyle.gd")

const EVENT_KEYS: Array[Dictionary] = [
	{"label": "1B", "event_type": "single", "implemented": true, "hint": "Single", "shortcut": "S"},
	{"label": "2B", "event_type": "double", "implemented": true, "hint": "Double", "shortcut": "D"},
	{"label": "3B", "event_type": "triple", "implemented": true, "hint": "Triple", "shortcut": "T"},
	{"label": "HR", "event_type": "home_run", "implemented": true, "hint": "Home run", "shortcut": "H"},
	{"label": "BB", "event_type": "walk", "implemented": true, "hint": "Walk", "shortcut": "W"},
	{"label": "HBP", "event_type": "hit_by_pitch", "implemented": true, "hint": "Hit by pitch"},
	{"label": "K", "event_type": "strikeout", "implemented": true, "hint": "Strikeout", "shortcut": "K"},
	{"label": "GO", "event_type": "groundout", "implemented": true, "hint": "Groundout", "shortcut": "G"},
	{"label": "FO", "event_type": "flyout", "implemented": true, "hint": "Flyout", "shortcut": "F"},
	{"label": "E", "event_type": "reached_on_error", "implemented": true, "hint": "Reached on error", "shortcut": "E"},
	{"label": "FC", "event_type": "fielders_choice", "implemented": true, "hint": "Fielder's choice", "shortcut": "C"},
	{"label": "SAC", "event_type": "sacrifice", "implemented": false, "hint": "Sacrifice"},
	{"label": "SB", "event_type": "stolen_base", "implemented": true, "hint": "Stolen base", "shortcut": "B"},
	{"label": "CS", "event_type": "caught_stealing", "implemented": true, "hint": "Caught stealing"},
	{"label": "WP", "event_type": "wild_pitch", "implemented": true, "hint": "Wild pitch"},
	{"label": "PB", "event_type": "passed_ball", "implemented": true, "hint": "Passed ball"},
	{"label": "BK", "event_type": "balk", "implemented": true, "hint": "Balk"},
	{"label": "DP", "event_type": "double_play", "implemented": true, "hint": "Double play"},
	{"label": "TP", "event_type": "triple_play", "implemented": true, "hint": "Triple play"},
	{"label": "SUB", "event_type": "substitution", "implemented": true, "hint": "Substitution", "shortcut": "U"},
	{"label": "PCH", "event_type": "pitching_change", "implemented": true, "hint": "Pitching change", "shortcut": "P"},
	{"label": "MAN", "event_type": "manual_correction", "implemented": true, "hint": "Manual correction"},
]

@onready var title_label: Label = %EventKeysLabel
@onready var event_buttons_scroll: ScrollContainer = %EventButtonsScroll
@onready var event_buttons_grid: GridContainer = %EventButtonsGrid

var _event_buttons_by_type: Dictionary = {}
var _selected_event_type := ""

func _ready() -> void:
	_build_event_key_buttons()
	_apply_style()

func apply_responsive_density(compact: bool, ultra_compact: bool) -> void:
	event_buttons_scroll.custom_minimum_size.y = 176.0 if ultra_compact else 204.0 if compact else 260.0
	event_buttons_grid.add_theme_constant_override(&"h_separation", 4 if ultra_compact else 6)
	event_buttons_grid.add_theme_constant_override(&"v_separation", 4 if ultra_compact else 6)
	for button in _event_buttons_by_type.values():
		button.custom_minimum_size = Vector2(56, 28) if ultra_compact else Vector2(64, 30) if compact else Vector2(72, 34)

func get_selected_event_type() -> String:
	return _selected_event_type

func activate_event_type(event_type: String) -> bool:
	if not _event_buttons_by_type.has(event_type):
		return false
	var button: Button = _event_buttons_by_type[event_type]
	if button.disabled:
		return false
	_on_event_key_pressed(event_type)
	return true

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
		button.tooltip_text = _event_key_tooltip(event_config, implemented)
		button.pressed.connect(func() -> void: _on_event_key_pressed(event_type))
		event_buttons_grid.add_child(button)
		_event_buttons_by_type[event_type] = button

func _apply_style() -> void:
	GameEntryStyle.style_content_panel(self)
	GameEntryStyle.style_title_label(title_label)
	for button in _event_buttons_by_type.values():
		GameEntryStyle.style_button(button)

func _event_key_tooltip(event_config: Dictionary, implemented: bool) -> String:
	var hint := str(event_config.get("hint", event_config.get("event_type", "")))
	var event_type := str(event_config.get("event_type", ""))
	var shortcut := str(event_config.get("shortcut", "")).strip_edges()
	var shortcut_hint := "Shortcut: %s" % shortcut if not shortcut.is_empty() else "No shortcut assigned"
	var suffix := "Select %s event" % event_type
	return "%s — %s — %s" % [hint, shortcut_hint, suffix] if implemented else "%s — future event type disabled for now" % hint

func _on_event_key_pressed(event_type: String) -> void:
	_select_event_key(event_type)
	event_type_selected.emit(event_type)

func _select_event_key(event_type: String) -> void:
	if _selected_event_type == event_type:
		return
	if _event_buttons_by_type.has(_selected_event_type):
		GameEntryStyle.set_button_selected(_event_buttons_by_type[_selected_event_type], false)
	_selected_event_type = event_type
	if _event_buttons_by_type.has(_selected_event_type):
		GameEntryStyle.set_button_selected(_event_buttons_by_type[_selected_event_type], true)
