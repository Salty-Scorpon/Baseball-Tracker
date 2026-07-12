extends PanelContainer
class_name EventKeyPanel

signal event_type_selected(event_type: String)

const GameEntryStyle = preload("res://modes/game_entry/GameEntryStyle.gd")

const EVENT_KEYS: Array[Dictionary] = [
	{"label": "1B", "event_type": "single", "implemented": true, "hint": "Single"},
	{"label": "2B", "event_type": "double", "implemented": true, "hint": "Double"},
	{"label": "3B", "event_type": "triple", "implemented": true, "hint": "Triple"},
	{"label": "HR", "event_type": "home_run", "implemented": true, "hint": "Home run"},
	{"label": "BB", "event_type": "walk", "implemented": true, "hint": "Walk"},
	{"label": "HBP", "event_type": "hit_by_pitch", "implemented": true, "hint": "Hit by pitch"},
	{"label": "K", "event_type": "strikeout", "implemented": true, "hint": "Strikeout"},
	{"label": "GO", "event_type": "groundout", "implemented": true, "hint": "Groundout"},
	{"label": "FO", "event_type": "flyout", "implemented": true, "hint": "Flyout"},
	{"label": "E", "event_type": "reached_on_error", "implemented": true, "hint": "Reached on error"},
	{"label": "FC", "event_type": "fielders_choice", "implemented": true, "hint": "Fielder's choice"},
	{"label": "SAC", "event_type": "sacrifice", "implemented": false, "hint": "Sacrifice"},
	{"label": "SB", "event_type": "stolen_base", "implemented": true, "hint": "Stolen base"},
	{"label": "CS", "event_type": "caught_stealing", "implemented": true, "hint": "Caught stealing"},
	{"label": "WP", "event_type": "wild_pitch", "implemented": true, "hint": "Wild pitch"},
	{"label": "PB", "event_type": "passed_ball", "implemented": true, "hint": "Passed ball"},
	{"label": "BK", "event_type": "balk", "implemented": true, "hint": "Balk"},
	{"label": "DP", "event_type": "double_play", "implemented": true, "hint": "Double play"},
	{"label": "TP", "event_type": "triple_play", "implemented": true, "hint": "Triple play"},
	{"label": "SUB", "event_type": "substitution", "implemented": true, "hint": "Substitution"},
	{"label": "PCH", "event_type": "pitching_change", "implemented": true, "hint": "Pitching change"},
	{"label": "MAN", "event_type": "manual_correction", "implemented": true, "hint": "Manual correction"},
]

@onready var title_label: Label = %EventKeysLabel
@onready var event_buttons_grid: GridContainer = %EventButtonsGrid

var _event_buttons_by_type: Dictionary = {}
var _selected_event_type := ""

func _ready() -> void:
	_build_event_key_buttons()
	_apply_style()

func get_selected_event_type() -> String:
	return _selected_event_type

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
	var suffix := "Select %s event" % event_type
	return "%s — %s" % [hint, suffix] if implemented else "%s — future event type disabled for now" % hint

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
