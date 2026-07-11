class_name GameEvent
extends RefCounted

var id: String
var game_id: String
var sequence_number: int
var inning: int
var half_inning: String
var offensive_team_id: String
var defensive_team_id: String
var batter_id: String
var pitcher_id: String
var fielder_ids: Array[String]
var runner_ids: Array[String]
var event_type: String
var result: String
var rbi_count: int
var outs_added: int
var runs_scored: int
var base_state_before: Dictionary
var base_state_after: Dictionary
var earned_run_override: Variant
var notes: String
var manual_override: bool
var details: Dictionary

func _init(p_id: String = "", p_game_id: String = "") -> void:
	id = p_id
	game_id = p_game_id
	sequence_number = 0
	inning = 1
	half_inning = "top"
	offensive_team_id = ""
	defensive_team_id = ""
	batter_id = ""
	pitcher_id = ""
	fielder_ids = []
	runner_ids = []
	event_type = ""
	result = ""
	rbi_count = 0
	outs_added = 0
	runs_scored = 0
	base_state_before = {}
	base_state_after = {}
	earned_run_override = null
	notes = ""
	manual_override = false
	details = {}

func to_dict() -> Dictionary:
	return {
		"id": id, "game_id": game_id, "sequence_number": sequence_number, "inning": inning,
		"half_inning": half_inning, "offensive_team_id": offensive_team_id, "defensive_team_id": defensive_team_id,
		"batter_id": batter_id, "pitcher_id": pitcher_id, "fielder_ids": fielder_ids.duplicate(),
		"runner_ids": runner_ids.duplicate(), "event_type": event_type, "result": result, "rbi_count": rbi_count,
		"outs_added": outs_added, "runs_scored": runs_scored, "base_state_before": base_state_before.duplicate(true),
		"base_state_after": base_state_after.duplicate(true), "earned_run_override": earned_run_override,
		"notes": notes, "manual_override": manual_override, "details": details.duplicate(true),
	}

static func from_dict(data: Dictionary) -> GameEvent:
	var event := GameEvent.new(str(data.get("id", "")), str(data.get("game_id", "")))
	event.sequence_number = int(data.get("sequence_number", 0))
	event.inning = int(data.get("inning", 1))
	event.half_inning = str(data.get("half_inning", "top"))
	event.offensive_team_id = str(data.get("offensive_team_id", ""))
	event.defensive_team_id = str(data.get("defensive_team_id", ""))
	event.batter_id = str(data.get("batter_id", ""))
	event.pitcher_id = str(data.get("pitcher_id", ""))
	event.fielder_ids.assign(data.get("fielder_ids", []))
	event.runner_ids.assign(data.get("runner_ids", []))
	event.event_type = str(data.get("event_type", ""))
	event.result = str(data.get("result", ""))
	event.rbi_count = int(data.get("rbi_count", 0))
	event.outs_added = int(data.get("outs_added", 0))
	event.runs_scored = int(data.get("runs_scored", 0))
	event.base_state_before = Dictionary(data.get("base_state_before", {})).duplicate(true)
	event.base_state_after = Dictionary(data.get("base_state_after", {})).duplicate(true)
	event.earned_run_override = data.get("earned_run_override", null)
	event.notes = str(data.get("notes", ""))
	event.manual_override = bool(data.get("manual_override", false))
	event.details = Dictionary(data.get("details", {})).duplicate(true)
	return event

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.strip_edges().is_empty(): errors.append("GameEvent id is required.")
	if game_id.strip_edges().is_empty(): errors.append("GameEvent game_id is required.")
	if sequence_number < 0: errors.append("GameEvent sequence_number cannot be negative.")
	if inning <= 0: errors.append("GameEvent inning must be greater than zero.")
	if not ["top", "bottom"].has(half_inning): errors.append("GameEvent half_inning must be top or bottom.")
	return errors
