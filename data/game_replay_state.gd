class_name GameReplayState
extends RefCounted

var inning: int
var half_inning: String
var outs: int
var score: Dictionary
var bases: Dictionary
var batter_progression: Dictionary
var current_pitchers: Dictionary
var pitcher_assignments: Array[Dictionary]
var applied_event_ids: Array[String]

func _init() -> void:
	reset()

func reset() -> void:
	inning = 1
	half_inning = "top"
	outs = 0
	score = {"away": 0, "home": 0}
	bases = {"1B": "", "2B": "", "3B": ""}
	batter_progression = {"away": [], "home": []}
	current_pitchers = {"away": "", "home": ""}
	pitcher_assignments = []
	applied_event_ids = []

func duplicate_state() -> GameReplayState:
	var copy = GameReplayState.new()
	copy.inning = inning
	copy.half_inning = half_inning
	copy.outs = outs
	copy.score = score.duplicate(true)
	copy.bases = bases.duplicate(true)
	copy.batter_progression = batter_progression.duplicate(true)
	copy.current_pitchers = current_pitchers.duplicate(true)
	copy.pitcher_assignments = pitcher_assignments.duplicate(true)
	copy.applied_event_ids = applied_event_ids.duplicate()
	return copy

func to_dict() -> Dictionary:
	return {
		"inning": inning,
		"half_inning": half_inning,
		"outs": outs,
		"score": score.duplicate(true),
		"bases": bases.duplicate(true),
		"batter_progression": batter_progression.duplicate(true),
		"current_pitchers": current_pitchers.duplicate(true),
		"pitcher_assignments": pitcher_assignments.duplicate(true),
		"applied_event_ids": applied_event_ids.duplicate(),
	}
