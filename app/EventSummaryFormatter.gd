class_name EventSummaryFormatter
extends RefCounted

## Formats a pending Game Entry payload or saved GameEvent into one readable
## paragraph for pre-commit review.
##
## This class is intentionally UI-free and stat-calculation-free. It only reads
## already-collected canonical event fields plus event-specific values stored in
## details, then returns display text that callers can show anywhere.

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

const EVENT_LABELS = {
	"single": "singles",
	"double": "doubles",
	"triple": "triples",
	"home_run": "hits a home run",
	"walk": "walks",
	"hit_by_pitch": "is hit by a pitch",
	"strikeout": "strikes out",
	"groundout": "grounds out",
	"flyout": "flies out",
}

static func summarize(event_payload: Variant) -> String:
	var event = _as_event_dictionary(event_payload)
	var details = _as_dictionary(event.get("details", {}))
	var parts: Array[String] = []

	var context = _format_game_context(event)
	if not context.is_empty():
		parts.append(context)

	parts.append(_format_matchup_and_result(event, details))

	var count = _format_count(_as_dictionary(details.get("count", event.get("count", {}))))
	if not count.is_empty():
		parts.append(count)

	var contact = _format_batted_ball(details)
	if not contact.is_empty():
		parts.append(contact)

	var fielders = _format_fielder_assignment(details, event)
	if not fielders.is_empty():
		parts.append(fielders)

	var runners = _format_runner_advancements(_as_array(details.get("runner_advancements", event.get("runner_advancements", []))))
	if not runners.is_empty():
		parts.append(runners)

	var scoring = _format_scoring(event, details)
	if not scoring.is_empty():
		parts.append(scoring)

	var score = _format_score_after(_as_dictionary(event.get("score_after", details.get("score_after", {}))))
	if not score.is_empty():
		parts.append(score)

	var manual_note = _format_manual_override_note(event, details)
	if not manual_note.is_empty():
		parts.append(manual_note)

	return _join_sentences(parts)

static func format_summary(event_payload: Variant) -> String:
	return summarize(event_payload)

static func _as_event_dictionary(payload: Variant) -> Dictionary:
	if payload is Dictionary:
		return Dictionary(payload).duplicate(true)
	var event = {}
	for key in ["inning", "half", "half_inning", "outs_before", "event_type", "result", "batter_name", "batter_id", "pitcher_name", "pitcher_id", "runs_scored", "rbi", "rbi_count", "score_after", "details", "manual_overrides", "manual_override", "notes", "fielder_ids"]:
		var value: Variant = payload.get(key) if payload != null and payload.has_method("get") else null
		if value != null:
			event[key] = value
	return event

static func _format_game_context(event: Dictionary) -> String:
	var context: Array[String] = []
	var inning = int(event.get("inning", 0))
	if inning > 0:
		var half = str(event.get("half", event.get("half_inning", ""))).to_lower()
		context.append("%s of the %s" % [_half_label(half), _ordinal(inning)])
	if event.has("outs_before") and event.get("outs_before") != null:
		context.append("%s before the play" % _outs_label(int(event.get("outs_before", 0))))
	return ", ".join(context)

static func _format_matchup_and_result(event: Dictionary, details: Dictionary) -> String:
	var event_type = str(event.get("event_type", details.get("event_type", ""))).to_lower()
	var result = str(event.get("result", "")).strip_edges()
	var result_label = result if not result.is_empty() else str(EVENT_LABELS.get(event_type, event_type.replace("_", " ")))
	var batter = _person_label(event, details, "batter")
	var pitcher = _person_label(event, details, "pitcher")
	var text = batter if not batter.is_empty() else "The batter"
	text += " " + result_label
	if not pitcher.is_empty():
		text += " against " + pitcher
	return text

static func _format_count(count: Dictionary) -> String:
	if count.is_empty():
		return ""
	var bits: Array[String] = []
	if count.has("balls") or count.has("strikes"):
		bits.append("count %d-%d" % [int(count.get("balls", 0)), int(count.get("strikes", 0))])
	if count.has("total_pitches"):
		bits.append("%d total pitches" % int(count.get("total_pitches", 0)))
	return "Final " + ", ".join(bits) if not bits.is_empty() else ""

static func _format_batted_ball(details: Dictionary) -> String:
	var batted_ball = _as_dictionary(details.get("batted_ball", details.get("event_details", {})))
	var kind = _humanize(str(batted_ball.get("type", batted_ball.get("batted_ball_type", ""))))
	var location = _humanize(str(batted_ball.get("location", batted_ball.get("hit_location", ""))))
	if kind.is_empty() and location.is_empty():
		return ""
	if not kind.is_empty() and not location.is_empty():
		return "%s to %s" % [kind.capitalize(), location]
	return (kind if not kind.is_empty() else "Hit location: " + location).capitalize()

static func _format_fielder_assignment(details: Dictionary, event: Dictionary) -> String:
	var fielder_assignment = _as_dictionary(details.get("fielder_assignment", details.get("fielders", {})))
	if fielder_assignment.is_empty() and not event.has("fielder_ids"):
		return ""
	var names: Array[String] = []
	for key in ["primary_fielder_name", "putout_fielder_name", "caught_by_name", "throw_to_base", "primary_fielder_id", "putout_fielder_id", "caught_by"]:
		var value = str(fielder_assignment.get(key, "")).strip_edges()
		if not value.is_empty() and not names.has(value):
			names.append(value)
	for value in _as_array(fielder_assignment.get("assist_fielder_names", fielder_assignment.get("assist_fielder_ids", event.get("fielder_ids", [])))):
		var label = str(value).strip_edges()
		if not label.is_empty() and not names.has(label):
			names.append(label)
	return "Fielders assigned: %s" % ", ".join(names) if not names.is_empty() else ""

static func _format_runner_advancements(advancements: Array) -> String:
	var labels: Array[String] = []
	for item in advancements:
		var adv = _as_dictionary(item)
		var runner = str(adv.get("runner_name", adv.get("runner_id", "runner")))
		var start_base = str(adv.get("start_base", "")).strip_edges()
		var end_base = str(adv.get("end_base", "")).strip_edges()
		if bool(adv.get("scored", false)):
			end_base = "home"
		var label = runner
		if not start_base.is_empty() and not end_base.is_empty():
			label += " from %s to %s" % [start_base, end_base]
		elif not end_base.is_empty():
			label += " to %s" % end_base
		if bool(adv.get("out", false)):
			label += " (out)"
		labels.append(label)
	return "Runner advances: %s" % "; ".join(labels) if not labels.is_empty() else ""

static func _format_scoring(event: Dictionary, details: Dictionary) -> String:
	var runs = int(event.get("runs_scored", details.get("runs_scored", 0)))
	var rbi = int(event.get("rbi", event.get("rbi_count", details.get("rbi", 0))))
	var bits: Array[String] = []
	if runs > 0:
		bits.append("%s scored" % _plural_count(runs, "run", "runs"))
	if rbi > 0:
		bits.append("%s" % _plural_count(rbi, "RBI", "RBI"))
	return ", ".join(bits).capitalize() if not bits.is_empty() else ""

static func _format_score_after(score_after: Dictionary) -> String:
	if score_after.is_empty():
		return ""
	if score_after.has("away") and score_after.has("home"):
		return "Score after the play: Away %s, Home %s" % [score_after.get("away"), score_after.get("home")]
	var bits: Array[String] = []
	for key in score_after.keys():
		bits.append("%s %s" % [_humanize(str(key)).capitalize(), score_after[key]])
	return "Score after the play: %s" % ", ".join(bits)

static func _format_manual_override_note(event: Dictionary, details: Dictionary) -> String:
	var overrides = _as_dictionary(details.get("manual_overrides", event.get("manual_overrides", {})))
	var notes = str(event.get("notes", details.get("notes", ""))).strip_edges()
	if bool(event.get("manual_override", false)) or not overrides.is_empty():
		return "Manual override noted%s" % (": " + notes if not notes.is_empty() else "")
	return ""

static func _person_label(event: Dictionary, details: Dictionary, role: String) -> String:
	return str(event.get(role + "_name", details.get(role + "_name", event.get(role + "_id", details.get(role + "_id", ""))))).strip_edges()

static func _join_sentences(parts: Array[String]) -> String:
	var clean: Array[String] = []
	for part in parts:
		var text = part.strip_edges().trim_suffix(".")
		if not text.is_empty():
			clean.append(text)
	return ". ".join(clean) + "." if not clean.is_empty() else "No event details entered yet."

static func _half_label(half: String) -> String:
	return "Top" if half == "top" else "Bottom" if half == "bottom" else "Half"

static func _ordinal(value: int) -> String:
	var suffix = "th"
	if value % 100 < 11 or value % 100 > 13:
		match value % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [value, suffix]

static func _outs_label(outs: int) -> String:
	return _plural_count(outs, "out", "outs")

static func _plural_count(count: int, singular: String, plural: String) -> String:
	return "%d %s" % [count, singular if count == 1 else plural]

static func _humanize(value: String) -> String:
	return value.strip_edges().replace("_", " ")

static func _as_dictionary(value: Variant) -> Dictionary:
	return Dictionary(value) if value is Dictionary else {}

static func _as_array(value: Variant) -> Array:
	return Array(value) if value is Array else []
