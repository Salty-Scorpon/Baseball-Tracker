class_name GameEvent
extends RefCounted

var id: String
var game_id: String
var sequence: int
var sequence_number: int
var inning: int
var half: String
var half_inning: String
var event_type: String
var event_group: String
var batter_id: String
var pitcher_id: String
var offense_team_id: String
var offensive_team_id: String
var defense_team_id: String
var defensive_team_id: String
var outs_before: int
var outs_after: int
var base_state_before: Dictionary
var base_state_after: Dictionary
var score_before: Dictionary
var score_after: Dictionary
var runs_scored: int
var details: Dictionary
var manual_overrides: Dictionary
var notes: String

# Legacy/basic-event fields retained so existing game entry and replay code keeps working.
var fielder_ids: Array[String]
var runner_ids: Array[String]
var result: String
var rbi_count: int
var outs_added: int
var earned_run_override: Variant
var manual_override: bool

func _init(p_id: String = "", p_game_id: String = "") -> void:
	id = p_id
	game_id = p_game_id
	sequence = 0
	sequence_number = 0
	inning = 1
	half = "top"
	half_inning = "top"
	event_type = ""
	event_group = ""
	batter_id = ""
	pitcher_id = ""
	offense_team_id = ""
	offensive_team_id = ""
	defense_team_id = ""
	defensive_team_id = ""
	outs_before = 0
	outs_after = 0
	base_state_before = {}
	base_state_after = {}
	score_before = {}
	score_after = {}
	runs_scored = 0
	details = {}
	manual_overrides = {}
	notes = ""
	fielder_ids = []
	runner_ids = []
	result = ""
	rbi_count = 0
	outs_added = 0
	earned_run_override = null
	manual_override = false

func to_dict() -> Dictionary:
	_sync_standard_fields_from_legacy_fields()
	return {
		"id": id,
		"game_id": game_id,
		"sequence": sequence,
		"sequence_number": sequence_number,
		"inning": inning,
		"half": half,
		"half_inning": half_inning,
		"event_type": event_type,
		"event_group": event_group,
		"batter_id": batter_id,
		"pitcher_id": pitcher_id,
		"offense_team_id": offense_team_id,
		"offensive_team_id": offensive_team_id,
		"defense_team_id": defense_team_id,
		"defensive_team_id": defensive_team_id,
		"outs_before": outs_before,
		"outs_after": outs_after,
		"base_state_before": base_state_before.duplicate(true),
		"base_state_after": base_state_after.duplicate(true),
		"score_before": score_before.duplicate(true),
		"score_after": score_after.duplicate(true),
		"runs_scored": runs_scored,
		"details": details.duplicate(true),
		"manual_overrides": manual_overrides.duplicate(true),
		"notes": notes,
		"fielder_ids": fielder_ids.duplicate(),
		"runner_ids": runner_ids.duplicate(),
		"result": result,
		"rbi_count": rbi_count,
		"outs_added": outs_added,
		"earned_run_override": earned_run_override,
		"manual_override": manual_override,
	}

static func from_dict(data: Dictionary) -> GameEvent:
	var event = GameEvent.new(str(data.get("id", "")), str(data.get("game_id", "")))
	event.sequence = int(data.get("sequence", data.get("sequence_number", 0)))
	event.sequence_number = int(data.get("sequence_number", event.sequence))
	event.inning = int(data.get("inning", 1))
	event.half = str(data.get("half", data.get("half_inning", "top"))).to_lower()
	event.half_inning = str(data.get("half_inning", event.half)).to_lower()
	event.event_type = str(data.get("event_type", ""))
	event.event_group = str(data.get("event_group", ""))
	event.batter_id = str(data.get("batter_id", ""))
	event.pitcher_id = str(data.get("pitcher_id", ""))
	event.offense_team_id = str(data.get("offense_team_id", data.get("offensive_team_id", "")))
	event.offensive_team_id = str(data.get("offensive_team_id", event.offense_team_id))
	event.defense_team_id = str(data.get("defense_team_id", data.get("defensive_team_id", "")))
	event.defensive_team_id = str(data.get("defensive_team_id", event.defense_team_id))
	event.outs_before = int(data.get("outs_before", 0))
	event.outs_after = int(data.get("outs_after", data.get("outs_added", 0)))
	event.base_state_before = Dictionary(data.get("base_state_before", {})).duplicate(true)
	event.base_state_after = Dictionary(data.get("base_state_after", {})).duplicate(true)
	event.score_before = Dictionary(data.get("score_before", {})).duplicate(true)
	event.score_after = Dictionary(data.get("score_after", {})).duplicate(true)
	event.runs_scored = int(data.get("runs_scored", 0))
	event.details = Dictionary(data.get("details", {})).duplicate(true)
	event.manual_overrides = Dictionary(data.get("manual_overrides", {})).duplicate(true)
	event.notes = str(data.get("notes", ""))
	event.fielder_ids.assign(data.get("fielder_ids", []))
	event.runner_ids.assign(data.get("runner_ids", []))
	event.result = str(data.get("result", ""))
	event.rbi_count = int(data.get("rbi_count", data.get("rbi", 0)))
	event.outs_added = int(data.get("outs_added", max(0, event.outs_after - event.outs_before)))
	event.earned_run_override = data.get("earned_run_override", null)
	event.manual_override = bool(data.get("manual_override", not event.manual_overrides.is_empty()))
	event._sync_standard_fields_from_legacy_fields()
	return event

func validate() -> PackedStringArray:
	_sync_standard_fields_from_legacy_fields()
	var errors = PackedStringArray()
	if id.strip_edges().is_empty(): errors.append("GameEvent id is required.")
	if game_id.strip_edges().is_empty(): errors.append("GameEvent game_id is required.")
	if sequence < 0: errors.append("GameEvent sequence cannot be negative.")
	if sequence_number < 0: errors.append("GameEvent sequence_number cannot be negative.")
	if inning <= 0: errors.append("GameEvent inning must be greater than zero.")
	if not ["top", "bottom"].has(half): errors.append("GameEvent half must be top or bottom.")
	if not ["top", "bottom"].has(half_inning): errors.append("GameEvent half_inning must be top or bottom.")
	if outs_before < 0 or outs_before > 2: errors.append("GameEvent outs_before must be between 0 and 2.")
	if outs_after < 0: errors.append("GameEvent outs_after cannot be negative.")
	return errors

func _sync_standard_fields_from_legacy_fields() -> void:
	if sequence == 0 and sequence_number != 0:
		sequence = sequence_number
	elif sequence_number == 0 and sequence != 0:
		sequence_number = sequence
	if half.is_empty() and not half_inning.is_empty():
		half = half_inning
	elif half_inning.is_empty() and not half.is_empty():
		half_inning = half
	half = half.to_lower()
	half_inning = half_inning.to_lower()
	if offense_team_id.is_empty() and not offensive_team_id.is_empty():
		offense_team_id = offensive_team_id
	elif offensive_team_id.is_empty() and not offense_team_id.is_empty():
		offensive_team_id = offense_team_id
	if defense_team_id.is_empty() and not defensive_team_id.is_empty():
		defense_team_id = defensive_team_id
	elif defensive_team_id.is_empty() and not defense_team_id.is_empty():
		defensive_team_id = defense_team_id
	if outs_after == 0 and outs_before == 0 and outs_added > 0:
		outs_after = outs_added
