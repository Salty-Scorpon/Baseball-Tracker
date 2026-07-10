extends SceneTree

const GameEventModel := preload("res://data/models/game_event.gd")
const GameReplay := preload("res://data/game_replay.gd")

func _init() -> void:
	var exit_code := 0
	var events := [
		_event("e1", 1, "Single", "away_batter_1", "home_pitcher_1", 0, 0),
		_event("e2", 2, "Double", "away_batter_2", "home_pitcher_1", 1, 0),
		_event("e3", 3, "Groundout", "away_batter_3", "home_pitcher_1", 0, 1),
		_event("e4", 4, "Groundout", "away_batter_4", "home_pitcher_1", 0, 1),
		_event("e5", 5, "Flyout", "away_batter_5", "home_pitcher_1", 0, 1),
		_event("e6", 6, "Pitching change", "home_batter_1", "away_pitcher_2", 0, 0),
		_event("e7", 7, "Home run", "home_batter_2", "away_pitcher_2", 2, 0),
	]

	var state := GameReplay.replay(events, {"away": "away_pitcher_1", "home": "home_pitcher_1"}, true)
	exit_code = _expect(state.score["away"] == 1 and state.score["home"] == 2, "Replay recalculates score from the same ordered event log.", exit_code)
	exit_code = _expect(state.inning == 1 and state.half_inning == "bottom" and state.outs == 0, "Replay rebuilds inning half and outs.", exit_code)
	exit_code = _expect(state.bases["1B"] == "" and state.bases["2B"] == "" and state.bases["3B"] == "", "Replay rebuilds base state after scoring plays.", exit_code)
	exit_code = _expect(state.batter_progression["away"] == ["away_batter_1", "away_batter_2", "away_batter_3", "away_batter_4", "away_batter_5"] and state.batter_progression["home"] == ["home_batter_1", "home_batter_2"], "Replay tracks deterministic batter progression.", exit_code)
	exit_code = _expect(state.current_pitchers["away"] == "away_pitcher_2" and state.current_pitchers["home"] == "home_pitcher_1", "Replay preserves current pitcher assignments where available.", exit_code)
	exit_code = _expect(events[5].inning == 1 and events[5].half_inning == "bottom" and events[0].base_state_after["1B"] == "away_batter_1", "Mutating replay canonicalizes event inning and base snapshots.", exit_code)

	events[1].event_type = "Triple"
	events[1].result = "Triple"
	var edited_state := GameReplay.replay(events, {"away": "away_pitcher_1", "home": "home_pitcher_1"}, true)
	exit_code = _expect(edited_state.score["away"] == 1 and edited_state.bases["3B"] == "away_batter_2", "Editing an earlier event and replaying recalculates later state canonically.", exit_code)

	quit(exit_code)

func _event(id: String, sequence_number: int, event_type: String, batter_id: String, pitcher_id: String, runs_scored: int, outs_added: int) -> GameEvent:
	var event := GameEventModel.new(id, "game_replay_test")
	event.sequence_number = sequence_number
	event.event_type = event_type
	event.result = event_type
	event.batter_id = batter_id
	event.pitcher_id = pitcher_id
	event.runs_scored = runs_scored
	event.outs_added = outs_added
	return event

func _expect(condition: bool, message: String, current_exit_code: int) -> int:
	if not condition:
		push_error(message)
		return 1
	return current_exit_code
