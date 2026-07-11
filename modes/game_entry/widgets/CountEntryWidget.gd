extends VBoxContainer
class_name CountEntryWidget

## Reusable count and pitch-total entry widget for Game Entry event templates.
##
## The values returned by this widget are event-specific input data. Callers
## should store them in GameEvent.details when creating or editing canonical
## game-log events.

const DEFAULT_COUNT_DATA := {
	"balls": 0,
	"strikes": 0,
	"total_pitches": 0,
	"called_strikes": 0,
	"swinging_strikes": 0,
	"fouls": 0,
	"balls_thrown": 0,
	"manual_pitch_count_override": false,
}

@onready var balls_spin: SpinBox = %BallsSpin
@onready var strikes_spin: SpinBox = %StrikesSpin
@onready var total_pitches_spin: SpinBox = %TotalPitchesSpin
@onready var advanced_toggle: CheckButton = %AdvancedToggle
@onready var advanced_fields: VBoxContainer = %AdvancedFields
@onready var called_strikes_spin: SpinBox = %CalledStrikesSpin
@onready var swinging_strikes_spin: SpinBox = %SwingingStrikesSpin
@onready var fouls_spin: SpinBox = %FoulsSpin
@onready var balls_thrown_spin: SpinBox = %BallsThrownSpin
@onready var manual_pitch_count_override_check: CheckBox = %ManualPitchCountOverrideCheck

func _ready() -> void:
	advanced_toggle.toggled.connect(_set_advanced_visible)
	_set_advanced_visible(advanced_toggle.button_pressed)
	reset()

func get_count_data() -> Dictionary:
	return {
		"balls": int(balls_spin.value),
		"strikes": int(strikes_spin.value),
		"total_pitches": int(total_pitches_spin.value),
		"called_strikes": int(called_strikes_spin.value),
		"swinging_strikes": int(swinging_strikes_spin.value),
		"fouls": int(fouls_spin.value),
		"balls_thrown": int(balls_thrown_spin.value),
		"manual_pitch_count_override": manual_pitch_count_override_check.button_pressed,
	}

func set_count_data(data: Dictionary) -> void:
	var merged := DEFAULT_COUNT_DATA.duplicate(true)
	merged.merge(data, true)
	balls_spin.value = clampi(int(merged["balls"]), 0, 3)
	strikes_spin.value = clampi(int(merged["strikes"]), 0, 2)
	total_pitches_spin.value = max(0, int(merged["total_pitches"]))
	called_strikes_spin.value = max(0, int(merged["called_strikes"]))
	swinging_strikes_spin.value = max(0, int(merged["swinging_strikes"]))
	fouls_spin.value = max(0, int(merged["fouls"]))
	balls_thrown_spin.value = max(0, int(merged["balls_thrown"]))
	manual_pitch_count_override_check.button_pressed = bool(merged["manual_pitch_count_override"])

func reset() -> void:
	set_count_data(DEFAULT_COUNT_DATA)

func validate() -> Array[String]:
	var errors: Array[String] = []
	var count_data := get_count_data()
	if count_data["balls"] < 0 or count_data["balls"] > 3:
		errors.append("Balls must be between 0 and 3.")
	if count_data["strikes"] < 0 or count_data["strikes"] > 2:
		errors.append("Strikes must be between 0 and 2.")
	for field_name in ["total_pitches", "called_strikes", "swinging_strikes", "fouls", "balls_thrown"]:
		if int(count_data[field_name]) < 0:
			errors.append("%s cannot be negative." % _humanize_field_name(field_name))
	if not count_data["manual_pitch_count_override"]:
		var visible_pitch_parts := int(count_data["called_strikes"]) + int(count_data["swinging_strikes"]) + int(count_data["fouls"]) + int(count_data["balls_thrown"])
		if visible_pitch_parts > int(count_data["total_pitches"]):
			errors.append("Advanced pitch details cannot exceed total pitches unless manual override is enabled.")
	return errors

func _set_advanced_visible(is_visible: bool) -> void:
	advanced_fields.visible = is_visible

func _humanize_field_name(field_name: String) -> String:
	return field_name.capitalize()
