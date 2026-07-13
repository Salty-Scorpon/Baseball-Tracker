extends PanelContainer
class_name ActivePitcherPanel

signal select_starting_pitchers_requested

const GameEntryStyle = preload("res://modes/game_entry/GameEntryStyle.gd")

@onready var title_label: Label = %ActivePitcherTitleLabel
@onready var home_pitcher_value: Label = %HomePitcherValue
@onready var away_pitcher_value: Label = %AwayPitcherValue
@onready var select_button: Button = %SelectStartingPitchersButton

func _ready() -> void:
	_apply_style()
	select_button.pressed.connect(func() -> void: select_starting_pitchers_requested.emit())
	clear()

func set_pitchers(home_pitcher_name: String, away_pitcher_name: String) -> void:
	home_pitcher_value.text = _display_name(home_pitcher_name)
	away_pitcher_value.text = _display_name(away_pitcher_name)

func clear() -> void:
	set_pitchers("", "")

func _display_name(value: String) -> String:
	var clean = value.strip_edges()
	return clean if not clean.is_empty() else "No pitcher selected"

func _apply_style() -> void:
	GameEntryStyle.style_content_panel(self)
	GameEntryStyle.style_title_label(title_label)
	for label in [home_pitcher_value, away_pitcher_value]:
		GameEntryStyle.style_body_label(label)
	GameEntryStyle.style_button(select_button)
