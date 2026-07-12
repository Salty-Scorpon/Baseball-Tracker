class_name GameReplay
extends RefCounted

const GameReplayStateModel = preload("res://data/game_replay_state.gd")
const ADVANCE_EVENTS = {"single": 1, "double": 2, "triple": 3, "home_run": 4, "walk": 1, "hit_by_pitch": 1, "reached_on_error": 1, "fielders_choice": 1}

static func initial_state(starting_pitchers: Dictionary = {}) -> GameReplayState:
	var state = GameReplayStateModel.new()
	state.current_pitchers["away"] = str(starting_pitchers.get("away", ""))
	state.current_pitchers["home"] = str(starting_pitchers.get("home", ""))
	return state

static func replay(events: Array, starting_pitchers: Dictionary = {}, mutate_events: bool = false) -> GameReplayState:
	var state = initial_state(starting_pitchers)
	var ordered = events.duplicate()
	ordered.sort_custom(_sort_events)
	for event in ordered:
		apply_event(state, event, mutate_events)
	return state

static func replay_until(events: Array, sequence_number: int, starting_pitchers: Dictionary = {}, mutate_events: bool = false) -> GameReplayState:
	return replay(events.filter(func(event: GameEvent) -> bool: return event.sequence_number <= sequence_number), starting_pitchers, mutate_events)

static func apply_event(state: GameReplayState, event: GameEvent, mutate_event: bool = false) -> void:
	if mutate_event:
		event.inning = state.inning
		event.half_inning = state.half_inning
		event.base_state_before = state.bases.duplicate(true)
	_record_batter(state, event)
	_record_pitcher(state, event)
	_apply_runner_substitution(state, event)
	var normalized_event_type := _normalized_event_type(event)
	if ADVANCE_EVENTS.has(normalized_event_type):
		_advance_runners(state, int(ADVANCE_EVENTS[normalized_event_type]), event.batter_id, normalized_event_type == "home_run")
	elif normalized_event_type == "stolen_base":
		_steal_one_base(state)
	_add_runs(state, event.runs_scored)
	state.outs += event.outs_added
	while state.outs >= 3:
		state.outs -= 3
		state.bases = {"1B": "", "2B": "", "3B": ""}
		if state.half_inning == "top":
			state.half_inning = "bottom"
		else:
			state.half_inning = "top"
			state.inning += 1
	state.applied_event_ids.append(event.id)
	if mutate_event:
		event.base_state_after = state.bases.duplicate(true)

static func _sort_events(a: GameEvent, b: GameEvent) -> bool:
	if a.sequence_number == b.sequence_number:
		return a.id < b.id
	return a.sequence_number < b.sequence_number

static func _record_batter(state: GameReplayState, event: GameEvent) -> void:
	if event.batter_id.is_empty():
		return
	var side = _side_for_half(event.half_inning)
	state.batter_progression[side].append(event.batter_id)

static func _record_pitcher(state: GameReplayState, event: GameEvent) -> void:
	var defense_side = "home" if event.half_inning == "top" else "away"
	if not event.pitcher_id.is_empty():
		state.current_pitchers[defense_side] = event.pitcher_id
	if _normalized_event_type(event) == "pitching_change" and not event.pitcher_id.is_empty():
		state.pitcher_assignments.append({"sequence_number": event.sequence_number, "half_inning": event.half_inning, "inning": event.inning, "team_side": defense_side, "pitcher_id": event.pitcher_id})

static func _normalized_event_type(event: GameEvent) -> String:
	return str(event.details.get("event_type", event.event_type)).strip_edges().to_lower().replace(" ", "_").replace("-", "_")

static func _advance_runners(state: GameReplayState, bases_to_advance: int, batter_id: String, clear_bases: bool = false) -> void:
	var old_bases = state.bases.duplicate(true)
	state.bases = {"1B": "", "2B": "", "3B": ""}
	for base_number in [3, 2, 1]:
		var runner = str(old_bases["%dB" % base_number])
		if runner.is_empty():
			continue
		var target = base_number + bases_to_advance
		if target <= 3:
			state.bases["%dB" % target] = runner
	if not batter_id.is_empty() and not clear_bases and bases_to_advance <= 3:
		state.bases["%dB" % bases_to_advance] = batter_id

static func _steal_one_base(state: GameReplayState) -> void:
	if not str(state.bases["2B"]).is_empty() and str(state.bases["3B"]).is_empty():
		state.bases["3B"] = state.bases["2B"]
		state.bases["2B"] = ""
	elif not str(state.bases["1B"]).is_empty() and str(state.bases["2B"]).is_empty():
		state.bases["2B"] = state.bases["1B"]
		state.bases["1B"] = ""

static func _apply_runner_substitution(state: GameReplayState, event: GameEvent) -> void:
	if _normalized_event_type(event) != "pinch_runner":
		return
	var substitution := Dictionary(event.details.get("substitution", {}))
	var player_out_id := str(substitution.get("player_out_id", ""))
	var player_in_id := str(substitution.get("player_in_id", ""))
	if player_out_id.is_empty() or player_in_id.is_empty():
		return
	for base in ["1B", "2B", "3B"]:
		if str(state.bases.get(base, "")) == player_out_id:
			state.bases[base] = player_in_id

static func _add_runs(state: GameReplayState, count: int) -> void:
	state.score[_side_for_half(state.half_inning)] += count

static func _side_for_half(value: String) -> String:
	return "away" if value == "top" else "home"
