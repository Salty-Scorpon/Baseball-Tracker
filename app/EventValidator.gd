class_name EventValidator
extends RefCounted

## Reusable validation service for expanded Game Entry event payloads.
##
## This service validates dictionaries produced by EventEntryPanel before callers
## convert them into canonical GameEvent records. It does not show UI, mutate
## payloads, or calculate stats. Event-specific values are expected to remain in
## payload["details"], especially details["count"],
## details["runner_advancements"], details["fielder_assignment"], and
## details["manual_overrides"].

const SEVERITY_ERROR = "error"
const SEVERITY_WARNING = "warning"

const SUPPORTED_EVENT_TYPES: Array[String] = [
	"single",
	"double",
	"triple",
	"home_run",
	"walk",
	"hit_by_pitch",
	"strikeout",
	"groundout",
	"flyout",
]

const PITCH_THROWN_EVENT_TYPES = {
	"single": true,
	"double": true,
	"triple": true,
	"home_run": true,
	"walk": true,
	"hit_by_pitch": true,
	"strikeout": true,
	"groundout": true,
	"flyout": true,
}

const BATTED_BALL_OUT_EVENT_TYPES = {
	"groundout": true,
	"flyout": true,
}

const ACTIVE_BASES = {"1B": true, "2B": true, "3B": true}

static func validate_event_payload(payload: Dictionary) -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	var event_type = _normalize_event_type(str(payload.get("event_type", "")))
	var details = _as_dictionary(payload.get("details", {}))
	var advancements = _as_array(details.get("runner_advancements", []))
	var count = _as_dictionary(details.get("count", {}))
	var fielder_assignment = _as_dictionary(details.get("fielder_assignment", {}))
	var manual_overrides = _as_dictionary(details.get("manual_overrides", payload.get("manual_overrides", {})))

	if event_type.is_empty():
		_add_error(messages, "event_type", "Event type is required.")
	elif not SUPPORTED_EVENT_TYPES.has(event_type):
		_add_error(messages, "event_type", "Unsupported event type for first-batch validation: %s." % event_type)

	if _is_blank(payload.get("batter_id", "")):
		_add_error(messages, "batter_id", "A plate appearance event must have a batter_id.")
	if PITCH_THROWN_EVENT_TYPES.has(event_type) and _is_blank(payload.get("pitcher_id", "")):
		_add_error(messages, "pitcher_id", "A pitch-thrown event must have a pitcher_id.")

	_validate_count(messages, event_type, count, manual_overrides)
	_validate_runner_advancements(messages, event_type, str(payload.get("batter_id", "")), advancements)
	_validate_outs(messages, event_type, payload, advancements, manual_overrides)
	_validate_fielder_assignment(messages, event_type, fielder_assignment)
	return messages

static func has_errors(messages: Array) -> bool:
	for message in messages:
		if message is Dictionary and str(message.get("severity", "")) == SEVERITY_ERROR:
			return true
	return false

static func errors_only(messages: Array) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for message in messages:
		if message is Dictionary and str(message.get("severity", "")) == SEVERITY_ERROR:
			output.append(message)
	return output

static func warnings_only(messages: Array) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for message in messages:
		if message is Dictionary and str(message.get("severity", "")) == SEVERITY_WARNING:
			output.append(message)
	return output

static func _validate_count(messages: Array[Dictionary], event_type: String, count: Dictionary, manual_overrides: Dictionary) -> void:
	var strikes = int(count.get("strikes", count.get("strikes_on_final_pitch", 0)))
	if event_type in ["walk", "hit_by_pitch"] and strikes > 2 and not _has_enabled_override(manual_overrides, "pitch_count"):
		_add_error(messages, "details.count.strikes", "%s cannot have more than 2 strikes in the final count." % event_type.capitalize())
	var balls = int(count.get("balls", count.get("balls_on_final_pitch", 0)))
	if balls < 0 or strikes < 0:
		_add_error(messages, "details.count", "Final count values cannot be negative.")

static func _validate_runner_advancements(messages: Array[Dictionary], event_type: String, batter_id: String, advancements: Array) -> void:
	var occupied_after = {}
	var batter_scored = false
	var saw_batter = false
	for index in range(advancements.size()):
		var advancement = _as_dictionary(advancements[index])
		var runner_id = str(advancement.get("runner_id", ""))
		var label = "runner %d" % (index + 1)
		var end_base = str(advancement.get("end_base", "")).to_upper()
		var scored = bool(advancement.get("scored", false)) or end_base == "SCORED"
		var is_out = bool(advancement.get("out", false)) or end_base == "OUT"
		if runner_id == batter_id and not batter_id.is_empty():
			saw_batter = true
			batter_scored = scored
		if scored and is_out:
			_add_error(messages, "details.runner_advancements[%d]" % index, "A runner cannot be both scored and out (%s)." % label)
		if ACTIVE_BASES.has(end_base) and not scored and not is_out:
			if occupied_after.has(end_base):
				_add_error(messages, "details.runner_advancements", "Two active runners cannot end on the same base (%s)." % end_base)
			else:
				occupied_after[end_base] = runner_id
	if event_type == "home_run" and (not saw_batter or not batter_scored):
		_add_error(messages, "details.runner_advancements", "A home run must score the batter.")

static func _validate_outs(messages: Array[Dictionary], event_type: String, payload: Dictionary, advancements: Array, manual_overrides: Dictionary) -> void:
	var outs_before = int(payload.get("outs_before", 0))
	var outs_after = int(payload.get("outs_after", outs_before + _outs_from_advancements(advancements)))
	var outs_added = max(0, outs_after - outs_before)
	if event_type == "strikeout" and outs_added < 1 and not _has_enabled_override(manual_overrides, "outs"):
		_add_warning(messages, "outs_after", "A strikeout should add at least one out unless manually overridden.")
	if BATTED_BALL_OUT_EVENT_TYPES.has(event_type) and outs_added < 1 and not _has_enabled_override(manual_overrides, "outs"):
		_add_warning(messages, "outs_after", "A normal batted-ball out should add at least one out.")
	if outs_after > 3 and not _has_enabled_override(manual_overrides, "outs"):
		_add_error(messages, "outs_after", "Outs after event cannot exceed 3 unless explicitly handled by game replay.")

static func _validate_fielder_assignment(messages: Array[Dictionary], event_type: String, fielder_assignment: Dictionary) -> void:
	if not BATTED_BALL_OUT_EVENT_TYPES.has(event_type):
		return
	var has_fielder = not _is_blank(fielder_assignment.get("primary_fielder_id", "")) or not _is_blank(fielder_assignment.get("putout_fielder_id", "")) or not _as_array(fielder_assignment.get("assist_fielder_ids", [])).is_empty()
	if not has_fielder:
		_add_warning(messages, "details.fielder_assignment", "Fielder assignment is unknown for this batted-ball out.")

static func _outs_from_advancements(advancements: Array) -> int:
	var total = 0
	for item in advancements:
		var advancement = _as_dictionary(item)
		if bool(advancement.get("out", false)) or str(advancement.get("end_base", "")).to_upper() == "OUT":
			total += 1
	return total

static func _has_enabled_override(manual_overrides: Dictionary, key: String) -> bool:
	var entry = manual_overrides.get(key, {})
	return entry is Dictionary and bool(entry.get("enabled", false))

static func _add_error(messages: Array[Dictionary], field: String, message: String) -> void:
	messages.append({"severity": SEVERITY_ERROR, "field": field, "message": message})

static func _add_warning(messages: Array[Dictionary], field: String, message: String) -> void:
	messages.append({"severity": SEVERITY_WARNING, "field": field, "message": message})

static func _normalize_event_type(event_type: String) -> String:
	return event_type.strip_edges().to_lower().replace(" ", "_").replace("-", "_")

static func _is_blank(value: Variant) -> bool:
	return str(value).strip_edges().is_empty()

static func _as_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

static func _as_array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []
