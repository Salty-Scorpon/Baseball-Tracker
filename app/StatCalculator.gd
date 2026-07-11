class_name StatCalculator
extends RefCounted

## Centralized event-log stat calculator.
##
## All derived baseball statistics should be calculated here instead of in UI
## scripts. Pitching volume is stored as integer outs_recorded; innings pitched is
## exposed as mathematical innings for formulas and as a separate baseball display
## string where one out is shown as .1 and two outs as .2.

const HIT_EVENTS = {"single": 1, "double": 2, "triple": 3, "home_run": 4}
const WALK_EVENTS = {"walk": true, "intentional_walk": true}
const HBP_EVENTS = {"hit_by_pitch": true, "hbp": true}
const STRIKEOUT_EVENTS = {"strikeout": true, "strike_out": true}
const OUT_EVENTS = {"groundout": true, "flyout": true, "lineout": true, "popout": true, "sacrifice_bunt": true, "sacrifice_fly": true, "fielders_choice": true, "double_play": true, "triple_play": true}

static func calculate_repository(repository: DataRepository) -> Dictionary:
	return calculate(repository.games, repository.game_events, repository.players, repository.teams)

static func calculate(games: Array, events: Array, players: Array = [], teams: Array = []) -> Dictionary:
	var games_by_id = _index_by_id(games)
	var player_team_ids = _player_team_ids(players)
	var sorted_events = events.duplicate()
	sorted_events.sort_custom(_sort_events)

	var result = {
		"player_batting": {},
		"player_pitching": {},
		"player_fielding": {},
		"team_batting": {},
		"team_pitching": {},
		"team_totals": {},
		"leaderboards": {},
	}
	var seen_player_batting_games := {}
	var seen_player_pitching_games := {}
	var seen_player_fielding_games := {}
	var seen_team_batting_games := {}
	var seen_team_pitching_games := {}
	var starting_pitchers := {}

	for event in sorted_events:
		if event == null:
			continue
		var game: Variant = games_by_id.get(event.game_id, null)
		var offense_team_id = _offense_team_id(event, game, player_team_ids)
		var defense_team_id = _defense_team_id(event, game, player_team_ids)
		var event_type = _event_type(event)
		var batter_id = _batter_id(event)
		var pitcher_id = _pitcher_id(event)
		var bases = int(HIT_EVENTS.get(event_type, 0))
		var outs = _outs_on_event(event)
		var runs = _runs_on_event(event)
		var rbi = _rbi_on_event(event, runs)
		var is_pa = _is_plate_appearance(event_type, event)
		var is_ab = _is_at_bat(event_type, event)

		if is_pa and not batter_id.is_empty():
			var batting = _ensure_batting(result.player_batting, batter_id)
			_mark_game(seen_player_batting_games, batting, batter_id, event.game_id)
			_apply_batting_event(batting, event, event_type, bases, _batter_runs_on_event(event_type, runs), rbi, is_ab)
		if is_pa and not offense_team_id.is_empty():
			var team_batting = _ensure_batting(result.team_batting, offense_team_id)
			_mark_game(seen_team_batting_games, team_batting, offense_team_id, event.game_id)
			_apply_batting_event(team_batting, event, event_type, bases, runs, rbi, is_ab)

		for runner_id in _scoring_runner_ids(event):
			if runner_id != batter_id:
				var runner_batting = _ensure_batting(result.player_batting, runner_id)
				_mark_game(seen_player_batting_games, runner_batting, runner_id, event.game_id)
				runner_batting.runs += 1

		if not pitcher_id.is_empty() and (is_pa or outs > 0 or runs > 0):
			var pitching = _ensure_pitching(result.player_pitching, pitcher_id)
			_mark_game(seen_player_pitching_games, pitching, pitcher_id, event.game_id)
			var starter_key = "%s:%s" % [event.game_id, defense_team_id]
			if not starting_pitchers.has(starter_key):
				starting_pitchers[starter_key] = pitcher_id
				pitching.games_started += 1
			_apply_pitching_event(pitching, event, event_type, bases, outs, runs)
		if not defense_team_id.is_empty() and (is_pa or outs > 0 or runs > 0):
			var team_pitching = _ensure_pitching(result.team_pitching, defense_team_id)
			_mark_game(seen_team_pitching_games, team_pitching, defense_team_id, event.game_id)
			_apply_pitching_event(team_pitching, event, event_type, bases, outs, runs)

		_apply_fielding_event(result.player_fielding, seen_player_fielding_games, event)

	_finalize_stat_map(result.player_batting, true)
	_finalize_stat_map(result.team_batting, true)
	_finalize_stat_map(result.player_pitching, false)
	_finalize_stat_map(result.team_pitching, false)
	_finalize_team_totals(result, teams)
	result.leaderboards = calculate_leaderboards(result)
	return result

static func calculate_leaderboards(stats: Dictionary, limit: int = 10) -> Dictionary:
	return {
		"batting_average": _leaderboard(stats.player_batting, "batting_average", limit, true),
		"home_runs": _leaderboard(stats.player_batting, "home_runs", limit, true),
		"rbi": _leaderboard(stats.player_batting, "rbi", limit, true),
		"era": _leaderboard(stats.player_pitching, "era", limit, false),
		"strikeouts": _leaderboard(stats.player_pitching, "strikeouts", limit, true),
	}

static func outs_to_innings(outs_recorded: int) -> float:
	return float(outs_recorded) / 3.0

static func outs_to_display_innings(outs_recorded: int) -> String:
	return "%d.%d" % [outs_recorded / 3, outs_recorded % 3]

static func _new_batting() -> Dictionary:
	return {"games": 0, "plate_appearances": 0, "at_bats": 0, "runs": 0, "hits": 0, "singles": 0, "doubles": 0, "triples": 0, "home_runs": 0, "rbi": 0, "walks": 0, "strikeouts": 0, "hit_by_pitch": 0, "sacrifice_bunts": 0, "sacrifice_flies": 0, "stolen_bases": 0, "caught_stealing": 0, "batting_average": 0.0, "on_base_percentage": 0.0, "slugging_percentage": 0.0, "ops": 0.0, "total_bases": 0}

static func _new_pitching() -> Dictionary:
	return {"games": 0, "games_started": 0, "innings_pitched": 0.0, "innings_pitched_display": "0.0", "outs_recorded": 0, "hits_allowed": 0, "runs_allowed": 0, "earned_runs": 0, "walks_allowed": 0, "strikeouts": 0, "home_runs_allowed": 0, "hit_batters": 0, "pitch_count": 0, "era": 0.0, "whip": 0.0}

static func _new_fielding() -> Dictionary:
	return {"games": 0, "putouts": 0, "assists": 0, "errors": 0, "double_plays": 0, "triple_plays": 0}

static func _ensure_batting(map: Dictionary, id: String) -> Dictionary:
	if not map.has(id): map[id] = _new_batting()
	return map[id]

static func _ensure_pitching(map: Dictionary, id: String) -> Dictionary:
	if not map.has(id): map[id] = _new_pitching()
	return map[id]

static func _ensure_fielding(map: Dictionary, id: String) -> Dictionary:
	if not map.has(id): map[id] = _new_fielding()
	return map[id]

static func _apply_batting_event(stats: Dictionary, event: GameEvent, event_type: String, bases: int, runs: int, rbi: int, is_ab: bool) -> void:
	stats.plate_appearances += 1
	if is_ab: stats.at_bats += 1
	stats.runs += runs
	stats.rbi += rbi
	if bases > 0:
		stats.hits += 1; stats.total_bases += bases
		if bases == 1: stats.singles += 1
		elif bases == 2: stats.doubles += 1
		elif bases == 3: stats.triples += 1
		elif bases == 4: stats.home_runs += 1
	elif WALK_EVENTS.has(event_type): stats.walks += 1
	elif HBP_EVENTS.has(event_type): stats.hit_by_pitch += 1
	elif STRIKEOUT_EVENTS.has(event_type): stats.strikeouts += 1
	elif event_type == "sacrifice_bunt" or bool(event.details.get("sacrifice_bunt", false)) or bool(_manual_overrides(event).get("sacrifice_bunt", false)): stats.sacrifice_bunts += 1
	elif event_type == "sacrifice_fly" or bool(event.details.get("sacrifice_fly", false)) or bool(_manual_overrides(event).get("sacrifice_fly", false)): stats.sacrifice_flies += 1
	elif event_type == "stolen_base": stats.stolen_bases += 1
	elif event_type == "caught_stealing": stats.caught_stealing += 1

static func _apply_pitching_event(stats: Dictionary, event: GameEvent, event_type: String, bases: int, outs: int, runs: int) -> void:
	stats.outs_recorded += outs
	stats.runs_allowed += runs
	stats.earned_runs += _earned_runs_on_event(event, runs)
	stats.pitch_count += _pitch_count_on_event(event)
	if bases > 0: stats.hits_allowed += 1
	if event_type == "home_run": stats.home_runs_allowed += 1
	elif WALK_EVENTS.has(event_type): stats.walks_allowed += 1
	elif STRIKEOUT_EVENTS.has(event_type): stats.strikeouts += 1
	elif HBP_EVENTS.has(event_type): stats.hit_batters += 1

static func _finalize_stat_map(map: Dictionary, batting: bool) -> void:
	for stats in map.values():
		if batting:
			stats.batting_average = _safe_div(stats.hits, stats.at_bats)
			stats.on_base_percentage = _safe_div(stats.hits + stats.walks + stats.hit_by_pitch, stats.at_bats + stats.walks + stats.hit_by_pitch + stats.sacrifice_flies)
			stats.slugging_percentage = _safe_div(stats.total_bases, stats.at_bats)
			stats.ops = stats.on_base_percentage + stats.slugging_percentage
		else:
			stats.innings_pitched = outs_to_innings(stats.outs_recorded)
			stats.innings_pitched_display = outs_to_display_innings(stats.outs_recorded)
			stats.era = _safe_div(stats.earned_runs * 27.0, stats.outs_recorded)
			stats.whip = _safe_div((stats.walks_allowed + stats.hits_allowed) * 3.0, stats.outs_recorded)

static func _finalize_team_totals(result: Dictionary, teams: Array) -> void:
	for team in teams:
		result.team_totals[team.id] = {"batting": result.team_batting.get(team.id, _new_batting()), "pitching": result.team_pitching.get(team.id, _new_pitching())}
	for team_id in result.team_batting.keys():
		if not result.team_totals.has(team_id): result.team_totals[team_id] = {"batting": result.team_batting[team_id], "pitching": result.team_pitching.get(team_id, _new_pitching())}
	for team_id in result.team_pitching.keys():
		if not result.team_totals.has(team_id): result.team_totals[team_id] = {"batting": result.team_batting.get(team_id, _new_batting()), "pitching": result.team_pitching[team_id]}

static func _apply_fielding_event(map: Dictionary, seen_games: Dictionary, event: GameEvent) -> void:
	var details = event.details
	var putout_id = str(details.get("putout_fielder_id", details.get("primary_fielder_id", "")))
	if not putout_id.is_empty():
		var po = _ensure_fielding(map, putout_id); _mark_game(seen_games, po, putout_id, event.game_id); po.putouts += _outs_on_event(event)
	for assist_id in _as_array(details.get("assist_fielder_ids", [])):
		var aid = str(assist_id)
		if not aid.is_empty():
			var ast = _ensure_fielding(map, aid); _mark_game(seen_games, ast, aid, event.game_id); ast.assists += 1
	for error_id in _as_array(details.get("error_fielder_ids", [])):
		var eid = str(error_id)
		if not eid.is_empty():
			var err = _ensure_fielding(map, eid); _mark_game(seen_games, err, eid, event.game_id); err.errors += 1

static func _is_plate_appearance(event_type: String, event: GameEvent) -> bool:
	return not _batter_id(event).is_empty() and (HIT_EVENTS.has(event_type) or WALK_EVENTS.has(event_type) or HBP_EVENTS.has(event_type) or STRIKEOUT_EVENTS.has(event_type) or OUT_EVENTS.has(event_type) or event_type == "sacrifice_bunt" or event_type == "sacrifice_fly")

static func _is_at_bat(event_type: String, event: GameEvent) -> bool:
	if WALK_EVENTS.has(event_type) or HBP_EVENTS.has(event_type) or event_type == "sacrifice_bunt" or event_type == "sacrifice_fly": return false
	var overrides = _manual_overrides(event)
	if bool(overrides.get("at_bat", true)) == false: return false
	if bool(event.details.get("sacrifice_bunt", false)) or bool(event.details.get("sacrifice_fly", false)) or bool(overrides.get("sacrifice_bunt", false)) or bool(overrides.get("sacrifice_fly", false)): return false
	return _is_plate_appearance(event_type, event)

static func _event_type(event: GameEvent) -> String:
	var value = event.details.get("event_type", event.event_type if not event.event_type.is_empty() else event.result)
	return str(value).strip_edges().to_lower().replace(" ", "_").replace("-", "_")

static func _batter_id(event: GameEvent) -> String:
	return str(event.details.get("batter_id", event.batter_id)).strip_edges()

static func _pitcher_id(event: GameEvent) -> String:
	return str(event.details.get("pitcher_id", event.pitcher_id)).strip_edges()

static func _outs_on_event(event: GameEvent) -> int:
	if event.details.has("outs_added"): return int(event.details.outs_added)
	if event.outs_added > 0: return event.outs_added
	return max(0, event.outs_after - event.outs_before)

static func _runs_on_event(event: GameEvent) -> int:
	var value = event.details.get("runs_scored", event.runs_scored)
	if value is Array:
		return value.size()
	return int(value)

static func _batter_runs_on_event(event_type: String, runs: int) -> int:
	return 1 if event_type == "home_run" and runs > 0 else 0

static func _rbi_on_event(event: GameEvent, runs: int) -> int:
	var overrides = _manual_overrides(event)
	return int(overrides.get("rbi", event.details.get("rbi", event.rbi_count if event.rbi_count > 0 else runs)))

static func _scoring_runner_ids(event: GameEvent) -> Array[String]:
	var ids: Array[String] = []
	for adv in _as_array(event.details.get("runner_advancements", [])):
		if adv is Dictionary and (bool(adv.get("scored", false)) or ["home", "score", "scored"].has(str(adv.get("end_base", adv.get("result", ""))).to_lower())): ids.append(str(adv.get("runner_id", "")))
	return ids

static func _offense_team_id(event: GameEvent, game: Variant, player_team_ids: Dictionary) -> String:
	if not event.offense_team_id.is_empty(): return event.offense_team_id
	if not event.offensive_team_id.is_empty(): return event.offensive_team_id
	var batter_id = _batter_id(event)
	if batter_id != "" and player_team_ids.has(batter_id): return player_team_ids[batter_id]
	return _team_for_half(game, event.half_inning, true)

static func _defense_team_id(event: GameEvent, game: Variant, player_team_ids: Dictionary) -> String:
	if not event.defense_team_id.is_empty(): return event.defense_team_id
	if not event.defensive_team_id.is_empty(): return event.defensive_team_id
	var pitcher_id = _pitcher_id(event)
	if pitcher_id != "" and player_team_ids.has(pitcher_id): return player_team_ids[pitcher_id]
	return _team_for_half(game, event.half_inning, false)

static func _team_for_half(game: Variant, half: String, offense: bool) -> String:
	if game == null: return ""
	var top = str(half).to_lower() == "top"
	return game.away_team_id if (top == offense) else game.home_team_id

static func _mark_game(seen: Dictionary, stats: Dictionary, subject_id: String, game_id: String) -> void:
	var key = "%s:%s" % [subject_id, game_id]
	if not seen.has(key): seen[key] = true; stats.games += 1

static func _index_by_id(items: Array) -> Dictionary:
	var output := {}
	for item in items:
		if item != null: output[item.id] = item
	return output

static func _player_team_ids(players: Array) -> Dictionary:
	var output := {}
	for player in players:
		if player != null: output[player.id] = player.team_id
	return output

static func _leaderboard(map: Dictionary, key: String, limit: int, descending: bool) -> Array:
	var rows := []
	for subject_id in map.keys(): rows.append({"id": subject_id, "value": map[subject_id].get(key, 0)})
	rows.sort_custom(func(a, b): return a.value > b.value if descending else a.value < b.value)
	return rows.slice(0, mini(limit, rows.size()))

static func _sort_events(a: GameEvent, b: GameEvent) -> bool:
	if a.game_id == b.game_id: return a.sequence_number < b.sequence_number
	return a.game_id < b.game_id

static func _earned_runs_on_event(event: GameEvent, runs: int) -> int:
	var overrides = _manual_overrides(event)
	if overrides.has("earned_runs"):
		return int(overrides.earned_runs)
	if overrides.has("earned_run"):
		return int(overrides.earned_run)
	if event.details.has("earned_runs"):
		return int(event.details.earned_runs)
	if event.details.has("earned_run"):
		return int(event.details.earned_run)
	if event.earned_run_override != null:
		return int(event.earned_run_override)
	return runs

static func _pitch_count_on_event(event: GameEvent) -> int:
	var count = event.details.get("count", {})
	if count is Dictionary:
		return int(count.get("total_pitches", count.get("pitch_count", 0)))
	return 0

static func _manual_overrides(event: GameEvent) -> Dictionary:
	var details_overrides = event.details.get("manual_overrides", {})
	if details_overrides is Dictionary and not details_overrides.is_empty():
		return details_overrides
	return event.manual_overrides if event.manual_overrides is Dictionary else {}

static func _safe_div(numerator: float, denominator: float) -> float:
	return 0.0 if denominator == 0.0 else numerator / denominator

static func _as_array(value: Variant) -> Array:
	return value if value is Array else []
