class_name GameStateSnapshot
extends RefCounted

const GameReplayScript = preload("res://data/game_replay.gd")

## Small adapter around GameReplay for UI snapshots. It keeps CompactScoreboardPanel
## display-only while preserving the event log/replay as the source of truth.
static func replay_game_until_sequence(events: Array, sequence_number: int = -1, player_names_by_id: Dictionary = {}, starting_pitchers: Dictionary = {}) -> Dictionary:
	var replay_state: GameReplayState = GameReplayScript.replay_until(events, sequence_number, starting_pitchers) if sequence_number >= 0 else GameReplayScript.replay(events, starting_pitchers)
	var half = str(replay_state.half_inning).strip_edges().to_lower()
	var defense_side = "home" if half == "top" else "away"
	var pitcher_id = str(replay_state.current_pitchers.get(defense_side, "")).strip_edges()
	return {
		"away_score": int(replay_state.score.get("away", 0)),
		"home_score": int(replay_state.score.get("home", 0)),
		"inning": int(replay_state.inning),
		"half": "Bottom" if half == "bottom" else "Top",
		"outs": int(replay_state.outs),
		"base_state": {
			"first": _empty_to_null(replay_state.bases.get("1B", "")),
			"second": _empty_to_null(replay_state.bases.get("2B", "")),
			"third": _empty_to_null(replay_state.bases.get("3B", "")),
		},
		"current_pitcher_id": pitcher_id,
		"current_pitcher_name": str(player_names_by_id.get(pitcher_id, pitcher_id)).strip_edges(),
		"current_pitcher_strikeouts": _strikeouts_for_pitcher_until(events, pitcher_id, sequence_number),
		"home_pitcher_id": str(replay_state.current_pitchers.get("home", "")).strip_edges(),
		"away_pitcher_id": str(replay_state.current_pitchers.get("away", "")).strip_edges(),
		"home_pitcher_name": str(player_names_by_id.get(str(replay_state.current_pitchers.get("home", "")).strip_edges(), str(replay_state.current_pitchers.get("home", "")).strip_edges())).strip_edges(),
		"away_pitcher_name": str(player_names_by_id.get(str(replay_state.current_pitchers.get("away", "")).strip_edges(), str(replay_state.current_pitchers.get("away", "")).strip_edges())).strip_edges(),
	}

static func get_game_state_at_event(events: Array, game_id: String, event_id: String, player_names_by_id: Dictionary = {}, starting_pitchers: Dictionary = {}) -> Dictionary:
	var game_events = _events_for_game(events, game_id)
	for event in game_events:
		if str(event.id) == event_id:
			return replay_game_until_sequence(game_events, int(event.sequence_number), player_names_by_id, starting_pitchers)
	return replay_game_until_sequence(game_events, -1, player_names_by_id, starting_pitchers)

static func _events_for_game(events: Array, game_id: String) -> Array:
	var output: Array = []
	for event in events:
		if game_id.is_empty() or str(event.game_id) == game_id:
			output.append(event)
	output.sort_custom(func(a: GameEvent, b: GameEvent) -> bool:
		if a.sequence_number == b.sequence_number:
			return a.id < b.id
		return a.sequence_number < b.sequence_number
	)
	return output

static func _strikeouts_for_pitcher_until(events: Array, pitcher_id: String, sequence_number: int = -1) -> int:
	if pitcher_id.is_empty():
		return 0
	var total = 0
	for event in events:
		if sequence_number >= 0 and int(event.sequence_number) > sequence_number:
			continue
		var event_type = str(event.details.get("event_type", event.event_type)).strip_edges().to_lower().replace(" ", "_").replace("-", "_")
		if str(event.pitcher_id).strip_edges() == pitcher_id and event_type.begins_with("strikeout"):
			total += 1
	return total

static func _empty_to_null(value: Variant) -> Variant:
	return null if str(value).strip_edges().is_empty() else value
