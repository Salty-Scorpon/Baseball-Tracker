extends Control

signal navigate_requested(screen_name: StringName)
signal event_key_selected(event_type: String)
signal add_player_requested

const EVENT_KEYS: Array[Dictionary] = [
	{"label": "1B", "event_type": "single", "implemented": false},
	{"label": "2B", "event_type": "double", "implemented": false},
	{"label": "3B", "event_type": "triple", "implemented": false},
	{"label": "HR", "event_type": "home_run", "implemented": false},
	{"label": "BB", "event_type": "walk", "implemented": false},
	{"label": "HBP", "event_type": "hit_by_pitch", "implemented": false},
	{"label": "K", "event_type": "strikeout", "implemented": false},
	{"label": "GO", "event_type": "groundout", "implemented": false},
	{"label": "FO", "event_type": "flyout", "implemented": false},
	{"label": "E", "event_type": "reached_on_error", "implemented": false},
	{"label": "FC", "event_type": "fielders_choice", "implemented": false},
	{"label": "SAC", "event_type": "sacrifice", "implemented": false},
	{"label": "SB", "event_type": "stolen_base", "implemented": false},
	{"label": "CS", "event_type": "caught_stealing", "implemented": false},
	{"label": "WP", "event_type": "wild_pitch", "implemented": false},
	{"label": "PB", "event_type": "passed_ball", "implemented": false},
	{"label": "BK", "event_type": "balk", "implemented": false},
	{"label": "DP", "event_type": "double_play", "implemented": false},
	{"label": "TP", "event_type": "triple_play", "implemented": false},
	{"label": "SUB", "event_type": "substitution", "implemented": false},
	{"label": "PCH", "event_type": "pitching_change", "implemented": false},
	{"label": "MAN", "event_type": "manual_correction", "implemented": false},
]

@onready var event_buttons_grid: GridContainer = %EventButtonsGrid
@onready var add_player_button: Button = %AddPlayerButton
@onready var shell_status_label: Label = %ShellStatusLabel

func _ready() -> void:
	_build_event_key_buttons()
	add_player_button.pressed.connect(_on_add_player_pressed)

func _build_event_key_buttons() -> void:
	for child in event_buttons_grid.get_children():
		child.queue_free()
	for event_config in EVENT_KEYS:
		var button := Button.new()
		button.text = str(event_config["label"])
		button.custom_minimum_size = Vector2(72, 34)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "%s placeholder" % str(event_config["event_type"]).replace("_", " ").capitalize()
		button.pressed.connect(func() -> void: _on_event_key_pressed(str(event_config["event_type"])))
		event_buttons_grid.add_child(button)

func _on_event_key_pressed(event_type: String) -> void:
	shell_status_label.text = "Selected event key: %s (placeholder shell only)." % event_type.replace("_", " ").capitalize()
	event_key_selected.emit(event_type)

func _on_add_player_pressed() -> void:
	shell_status_label.text = "Add Player requested (placeholder shell only)."
	add_player_requested.emit()
