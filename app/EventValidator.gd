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
	"reached_on_error",
	"fielders_choice",
	"sacrifice_bunt",
	"sacrifice_fly",
	"stolen_base",
	"caught_stealing",
	"wild_pitch",
	"passed_ball",
	"balk",
	"pitching_change",
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
	"reached_on_error": true,
	"fielders_choice": true,
	"sacrifice_bunt": true,
	"sacrifice_fly": true,
}

const BATTED_BALL_OUT_EVENT_TYPES = {
	"groundout": true,
	"flyout": true,
	"fielders_choice": true,
	"sacrifice_bunt": true,
	"sacrifice_fly": true,
}

const ACTIVE_BASES = {"1B": true, "2B": true, "3B": true}

static func validate_event_payload(payload: Dictionary) -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	var event_type = _normalize_event_type(str(payload.get("event_type", "")))
	var details = _as_dictionary(payload.get("details", {}))
	var advancements = _as_array(details.get("runner_advancements", []))
	var count = _as_dictionary(details.get("count", {}))
	var fielder_assignment = _as_dictionary(details.get("fielder_assignment", {}))
	var errors = _as_array(details.get("errors", []))
	var manual_overrides = _as_dictionary(details.get("manual_overrides", payload.get("manual_overrides", {})))

	if event_type.is_empty():
		_add_error(messages, "event_type", "Event type is required.")
	elif not SUPPORTED_EVENT_TYPES.has(event_type):
		_add_error(messages, "event_type", "Unsupported event type for validation: %s." % event_type)

	if not _is_runner_only_event(event_type) and event_type != "pitching_change" and _is_blank(payload.get("batter_id", "")):
		_add_error(messages, "batter_id", "A plate appearance event must have a batter_id.")
	if PITCH_THROWN_EVENT_TYPES.has(event_type) and _is_blank(payload.get("pitcher_id", "")):
		_add_error(messages, "pitcher_id", "A pitch-thrown event must have a pitcher_id.")

	_validate_count(messages, event_type, count, manual_overrides)
	_validate_runner_advancements(messages, event_type, str(payload.get("batter_id", "")), advancements)
	_validate_outs(messages, event_type, payload, advancements, manual_overrides)
	_validate_fielder_assignment(messages, event_type, fielder_assignment)
	_validate_batch_two_details(messages, event_type, payload, details, advancements, fielder_assignment, errors)
	_validate_pitching_change(messages, event_type, details)
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
	if event_type == "caught_stealing" and _outs_from_advancements(advancements) < 1:
		_add_error(messages, "details.runner_advancements", "Caught stealing must mark a runner out.")

static func _validate_outs(messages: Array[Dictionary], event_type: String, payload: Dictionary, advancements: Array, manual_overrides: Dictionary) -> void:
	var outs_before = int(payload.get("outs_before", 0))
	var outs_after = int(payload.get("outs_after", outs_before + _outs_from_advancements(advancements)))
	var outs_added = max(0, outs_after - outs_before)
	if event_type == "strikeout" and outs_added < 1 and not _has_enabled_override(manual_overrides, "outs"):
		_add_warning(messages, "outs_after", "A strikeout should add at least one out unless manually overridden.")
	if event_type == "caught_stealing" and outs_added < 1 and not _has_enabled_override(manual_overrides, "outs"):
		_add_error(messages, "outs_after", "Caught stealing must add an out.")
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

static func _validate_batch_two_details(messages: Array[Dictionary], event_type: String, payload: Dictionary, details: Dictionary, advancements: Array, fielder_assignment: Dictionary, errors: Array) -> void:
	var event_details = _flatten_event_details(_as_dictionary(details.get("event_details", {})))
	if event_type == "reached_on_error" and errors.is_empty() and _is_blank(event_details.get("error_fielder_id", "")) and _is_blank(fielder_assignment.get("primary_fielder_id", "")):
		_add_warning(messages, "details.errors", "Reached on error should attach at least one charged error or mark it with a manual override.")
	_validate_error_details(messages, errors)
	if event_type == "fielders_choice" and _outs_from_advancements(advancements) < 1:
		_add_warning(messages, "details.runner_advancements", "Fielder's choice usually records a runner out; mark the retired runner out or use an override.")
	if event_type in ["sacrifice_bunt", "sacrifice_fly"] and _outs_from_advancements(advancements) < 1:
		_add_warning(messages, "details.runner_advancements", "%s should record the batter out by default." % event_type.replace("_", " ").capitalize())
	if event_type == "sacrifice_fly" and _scored_runner_count(advancements) > 0 and _rbi_count(advancements) == 0:
		_add_warning(messages, "details.runner_advancements", "Sacrifice fly defaults to RBI credit for scoring runners unless overridden.")
	if event_type == "stolen_base" and advancements.is_empty():
		_add_error(messages, "details.runner_advancements", "Stolen base requires a runner advancement row.")
	if event_type in ["wild_pitch", "balk"] and _is_blank(event_details.get("pitcher_id", "")) and _is_blank(payload.get("pitcher_id", "")):
		_add_warning(messages, "details.event_details.pitcher_id", "%s should identify the pitcher." % event_type.replace("_", " ").capitalize())
	if event_type == "passed_ball" and _is_blank(event_details.get("catcher_id", "")) and _is_blank(fielder_assignment.get("primary_fielder_id", "")):
		_add_warning(messages, "details.event_details.catcher_id", "Passed ball should identify the catcher.")

static func _validate_pitching_change(messages: Array[Dictionary], event_type: String, details: Dictionary) -> void:
	if event_type != "pitching_change":
		return
	var pitching_change = _as_dictionary(details.get("pitching_change", {}))
	if _is_blank(pitching_change.get("incoming_pitcher_id", "")):
		_add_error(messages, "details.pitching_change.incoming_pitcher_id", "A pitching change must have an incoming pitcher.")
	if str(pitching_change.get("outgoing_pitcher_action", "")) == "move_to_position" and _is_blank(pitching_change.get("old_pitcher_new_position", "")):
		_add_warning(messages, "details.pitching_change.old_pitcher_new_position", "Enter the old pitcher new position or choose another outgoing action.")
	for index in range(_as_array(pitching_change.get("runner_responsibility", [])).size()):
		var entry = _as_dictionary(_as_array(pitching_change.get("runner_responsibility", []))[index])
		if _is_blank(entry.get("runner_id", "")) or _is_blank(entry.get("responsible_pitcher_id", "")) or _is_blank(entry.get("base", "")):
			_add_error(messages, "details.pitching_change.runner_responsibility[%d]" % index, "Runner responsibility requires runner_id, responsible_pitcher_id, and base.")

static func _validate_error_details(messages: Array[Dictionary], errors: Array) -> void:
	var valid_types = {"fielding": true, "throwing": true, "catching": true, "dropped_fly": true, "missed_tag": true, "missed_base": true, "interference": true, "unknown": true}
	var valid_phases = {"fielding_batted_ball": true, "throwing_after_fielding": true, "catching_throw": true, "dropped_fly": true, "missed_tag": true, "missed_base": true, "relay_error": true, "pickoff_error": true, "other": true}
	for index in range(errors.size()):
		var error = _as_dictionary(errors[index])
		if _is_blank(error.get("fielder_id", "")):
			_add_warning(messages, "details.errors[%d].fielder_id" % index, "Attached error should identify the fielder or an unknown/manual fielder ID.")
		if not valid_types.has(str(error.get("error_type", ""))):
			_add_error(messages, "details.errors[%d].error_type" % index, "Attached error has an invalid error_type.")
		if not valid_phases.has(str(error.get("error_phase", ""))):
			_add_error(messages, "details.errors[%d].error_phase" % index, "Attached error has an invalid error_phase.")
		if int(error.get("runs_scored_due_to_error", 0)) < 0:
			_add_error(messages, "details.errors[%d].runs_scored_due_to_error" % index, "Runs scored due to error cannot be negative.")

static func _flatten_event_details(event_details: Dictionary) -> Dictionary:
	var flat = {}
	for value in event_details.values():
		if value is Dictionary:
			flat.merge(value, true)
	return flat

static func _scored_runner_count(advancements: Array) -> int:
	var total = 0
	for item in advancements:
		var advancement = _as_dictionary(item)
		if bool(advancement.get("scored", false)) or str(advancement.get("end_base", "")).to_upper() == "SCORED":
			total += 1
	return total

static func _rbi_count(advancements: Array) -> int:
	var total = 0
	for item in advancements:
		if bool(_as_dictionary(item).get("rbi_credit", false)):
			total += 1
	return total

static func _is_runner_only_event(event_type: String) -> bool:
	return event_type in ["stolen_base", "caught_stealing", "wild_pitch", "passed_ball", "balk"]

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
