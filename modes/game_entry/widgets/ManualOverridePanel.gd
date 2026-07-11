extends VBoxContainer
class_name ManualOverridePanel

## Reusable scorer judgment-call panel for expanded Game Entry Mode.
##
## The panel only gathers optional, event-specific manual override data. Callers
## should store active override data in GameEvent.details so the canonical event
## log remains the source of truth. This script does not calculate or apply stats.

const OVERRIDE_KEYS: Array[String] = [
	"rbi",
	"earned_run",
	"hit_vs_error",
	"sacrifice_status",
	"at_bat_credit",
	"pitch_count",
	"fielder_assignment",
	"base_state",
	"outs",
	"score",
]

const BOOLEAN_KEYS := {"earned_run": true, "at_bat_credit": true}
const INTEGER_KEYS := {"rbi": true, "pitch_count": true, "outs": true}
const DICTIONARY_KEYS := {"base_state": true, "score": true, "fielder_assignment": true}

@onready var collapse_button: Button = %CollapseButton
@onready var rows_container: VBoxContainer = %RowsContainer
@onready var summary_label: Label = %SummaryLabel

var _controls := {}
var _is_collapsed := true
var _pending_overrides := {}

func _ready() -> void:
	collapse_button.pressed.connect(_toggle_collapsed)
	_build_rows()
	var startup_overrides := _pending_overrides.duplicate(true)
	reset()
	if not startup_overrides.is_empty():
		set_overrides(startup_overrides)
	_set_collapsed(true)

func get_overrides() -> Dictionary:
	var output := {}
	for key in OVERRIDE_KEYS:
		var row: Dictionary = _controls[key]
		output[key] = {
			"enabled": row["enabled"].button_pressed,
			"value": _read_value(key, row["value"].text),
			"reason": row["reason"].text.strip_edges(),
		}
	return output

func set_overrides(data: Dictionary) -> void:
	_pending_overrides = data.duplicate(true)
	if not is_node_ready():
		return
	for key in OVERRIDE_KEYS:
		var row: Dictionary = _controls[key]
		var entry := Dictionary(data.get(key, {}))
		row["enabled"].button_pressed = bool(entry.get("enabled", false))
		row["value"].text = _value_to_text(entry.get("value", null))
		row["reason"].text = str(entry.get("reason", ""))
	_update_summary()

func reset() -> void:
	var defaults := {}
	for key in OVERRIDE_KEYS:
		defaults[key] = {"enabled": false, "value": null, "reason": ""}
	set_overrides(defaults)

func has_active_overrides() -> bool:
	for entry in get_overrides().values():
		if bool(entry.get("enabled", false)):
			return true
	return false

func validate() -> Array[String]:
	var warnings: Array[String] = []
	var data := get_overrides()
	for key in OVERRIDE_KEYS:
		var entry: Dictionary = data[key]
		if not bool(entry["enabled"]):
			continue
		var row: Dictionary = _controls[key]
		var raw_value := str(row["value"].text).strip_edges()
		if raw_value.is_empty():
			warnings.append("%s override is enabled without a value." % _label_for_key(key))
		elif DICTIONARY_KEYS.has(key) and not entry["value"] is Dictionary:
			warnings.append("%s override value must be a JSON object/dictionary." % _label_for_key(key))
		elif INTEGER_KEYS.has(key) and not raw_value.is_valid_int():
			warnings.append("%s override value must be an integer." % _label_for_key(key))
		elif BOOLEAN_KEYS.has(key) and not _is_boolean_text(raw_value):
			warnings.append("%s override value must be true or false." % _label_for_key(key))
	return warnings

func _build_rows() -> void:
	for child in rows_container.get_children():
		child.queue_free()
	_controls.clear()
	for key in OVERRIDE_KEYS:
		var row := VBoxContainer.new()
		row.name = "%sRow" % key.to_pascal_case()
		var header := HBoxContainer.new()
		var enabled := CheckBox.new()
		enabled.text = _label_for_key(key)
		enabled.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		enabled.toggled.connect(func(_pressed: bool) -> void: _update_summary())
		header.add_child(enabled)
		row.add_child(header)
		var value := LineEdit.new()
		value.placeholder_text = _placeholder_for_key(key)
		value.text_changed.connect(func(_new_text: String) -> void: _update_summary())
		row.add_child(value)
		var reason := LineEdit.new()
		reason.placeholder_text = "Reason / scorer notes"
		reason.text_changed.connect(func(_new_text: String) -> void: _update_summary())
		row.add_child(reason)
		rows_container.add_child(row)
		_controls[key] = {"enabled": enabled, "value": value, "reason": reason}

func _toggle_collapsed() -> void:
	_set_collapsed(not _is_collapsed)

func _set_collapsed(collapsed: bool) -> void:
	_is_collapsed = collapsed
	rows_container.visible = not collapsed
	collapse_button.text = "Manual Overrides ▸" if collapsed else "Manual Overrides ▾"
	_update_summary()

func _update_summary() -> void:
	if not is_node_ready():
		return
	var active := []
	for key in OVERRIDE_KEYS:
		if _controls.has(key) and _controls[key]["enabled"].button_pressed:
			active.append(_label_for_key(key))
	summary_label.text = "No active manual overrides." if active.is_empty() else "Active: %s" % ", ".join(active)

func _read_value(key: String, raw_text: String) -> Variant:
	var text := raw_text.strip_edges()
	if text.is_empty():
		return null
	if INTEGER_KEYS.has(key):
		return int(text) if text.is_valid_int() else text
	if BOOLEAN_KEYS.has(key):
		if _is_boolean_text(text):
			return text.to_lower() in ["true", "yes", "1", "y"]
		return text
	if DICTIONARY_KEYS.has(key):
		var parsed := JSON.parse_string(text)
		return parsed if parsed is Dictionary else text
	return text

func _value_to_text(value: Variant) -> String:
	if value == null:
		return ""
	if value is Dictionary or value is Array:
		return JSON.stringify(value)
	return str(value)

func _is_boolean_text(text: String) -> bool:
	return text.to_lower() in ["true", "false", "yes", "no", "1", "0", "y", "n"]

func _label_for_key(key: String) -> String:
	return key.replace("_", " ").capitalize()

func _placeholder_for_key(key: String) -> String:
	if INTEGER_KEYS.has(key):
		return "Integer value"
	if BOOLEAN_KEYS.has(key):
		return "true or false"
	if DICTIONARY_KEYS.has(key):
		return "JSON object, e.g. {\"value\": \"manual\"}"
	return "Override value"
