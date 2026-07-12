extends PanelContainer
class_name CompactScoreboardPanel

const GameEntryStyle = preload("res://modes/game_entry/GameEntryStyle.gd")

@onready var title_label: Label = %ScoreboardTitleLabel
@onready var away_score_value: Label = %AwayScoreValue
@onready var home_score_value: Label = %HomeScoreValue
@onready var inning_value: Label = %InningValue
@onready var half_value: Label = %HalfValue
@onready var outs_value: Label = %OutsValue
@onready var first_base_label: Label = %FirstBaseLabel
@onready var second_base_label: Label = %SecondBaseLabel
@onready var third_base_label: Label = %ThirdBaseLabel
@onready var pitcher_name_value: Label = %PitcherNameValue
@onready var pitcher_id_value: Label = %PitcherIdValue
@onready var pitcher_strikeouts_value: Label = %PitcherStrikeoutsValue

func _ready() -> void:
	_apply_style()
	clear()

func set_state(state: Dictionary) -> void:
	away_score_value.text = str(int(state.get("away_score", 0)))
	home_score_value.text = str(int(state.get("home_score", 0)))
	inning_value.text = str(int(state.get("inning", 1)))
	half_value.text = _clean_half_label(str(state.get("half", "Top")))
	outs_value.text = "%d out%s" % [int(state.get("outs", 0)), "" if int(state.get("outs", 0)) == 1 else "s"]
	var base_state = Dictionary(state.get("base_state", {})) if state.get("base_state", {}) is Dictionary else {}
	_update_base_label(first_base_label, "1B", base_state.get("first", null))
	_update_base_label(second_base_label, "2B", base_state.get("second", null))
	_update_base_label(third_base_label, "3B", base_state.get("third", null))
	var pitcher_name = str(state.get("current_pitcher_name", "")).strip_edges()
	var pitcher_id = str(state.get("current_pitcher_id", "")).strip_edges()
	pitcher_name_value.text = pitcher_name if not pitcher_name.is_empty() else "No pitcher selected"
	pitcher_id_value.text = "ID: %s" % pitcher_id if not pitcher_id.is_empty() else "ID: —"
	pitcher_strikeouts_value.text = str(int(state.get("current_pitcher_strikeouts", 0)))

func clear() -> void:
	set_state({
		"away_score": 0,
		"home_score": 0,
		"inning": 1,
		"half": "Top",
		"outs": 0,
		"base_state": {"first": null, "second": null, "third": null},
		"current_pitcher_id": "",
		"current_pitcher_name": "",
		"current_pitcher_strikeouts": 0,
	})

func _update_base_label(label: Label, base_name: String, runner: Variant) -> void:
	var occupied = not _is_empty_runner(runner)
	label.text = "%s: %s" % [base_name, "occupied" if occupied else "empty"]
	label.add_theme_color_override("font_color", GameEntryStyle.ACCENT_COLOR if occupied else GameEntryStyle.MUTED_TEXT_COLOR)

func _is_empty_runner(runner: Variant) -> bool:
	return runner == null or str(runner).strip_edges().is_empty()

func _clean_half_label(raw_half: String) -> String:
	var normalized = raw_half.strip_edges().to_lower()
	if normalized == "bottom":
		return "Bottom"
	return "Top"

func _apply_style() -> void:
	GameEntryStyle.style_content_panel(self)
	GameEntryStyle.style_title_label(title_label)
	for label in [inning_value, half_value, outs_value, first_base_label, second_base_label, third_base_label, pitcher_id_value]:
		GameEntryStyle.style_body_label(label)
