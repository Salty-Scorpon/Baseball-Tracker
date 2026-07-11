extends SceneTree

const StatCalculator = preload("res://app/StatCalculator.gd")
const GameModel = preload("res://data/models/game.gd")
const GameEventModel = preload("res://data/models/game_event.gd")
const PlayerModel = preload("res://data/models/player.gd")
const TeamModel = preload("res://data/models/team.gd")

func _init() -> void:
	var exit_code = 0
	var away = TeamModel.new("away", "comp", "Away")
	var home = TeamModel.new("home", "comp", "Home")
	var players = [
		PlayerModel.new("away_b1", "away", "Away Batter 1"),
		PlayerModel.new("away_b2", "away", "Away Batter 2"),
		PlayerModel.new("away_b3", "away", "Away Batter 3"),
		PlayerModel.new("home_p1", "home", "Home Pitcher 1"),
	]
	var game = GameModel.new("game_1", "comp")
	game.away_team_id = "away"
	game.home_team_id = "home"
	game.status = "Final"
	var events = [
		_event("e1", 1, "single", "away_b1", "home_p1", 0, 0, {"rbi": 0}),
		_event("e2", 2, "home_run", "away_b2", "home_p1", 2, 0, {"rbi": 2, "runner_advancements": [{"runner_id": "away_b1", "end_base": "home"}]}),
		_event("e3", 3, "walk", "away_b3", "home_p1", 0, 0, {}),
		_event("e4", 4, "strikeout", "away_b1", "home_p1", 0, 1, {}),
		_event("e5", 5, "groundout", "away_b2", "home_p1", 0, 1, {}),
		_event("e6", 6, "flyout", "away_b3", "home_p1", 0, 1, {}),
	]
	var stats = StatCalculator.calculate([game], events, players, [away, home])
	var b1 = stats.player_batting.away_b1
	var b2 = stats.player_batting.away_b2
	var team_batting = stats.team_batting.away
	var pitcher = stats.player_pitching.home_p1

	exit_code = _expect(b1.games == 1 and b1.plate_appearances == 2 and b1.at_bats == 2 and b1.hits == 1 and b1.runs == 1 and b1.strikeouts == 1, "Player batting totals include hits, scored runner runs, and strikeouts.", exit_code)
	exit_code = _expect(b2.home_runs == 1 and b2.rbi == 2 and b2.total_bases == 4 and is_equal_approx(b2.slugging_percentage, 2.0), "Player batting formulas include home runs, RBI, total bases, and slugging.", exit_code)
	exit_code = _expect(team_batting.runs == 2 and team_batting.hits == 2 and team_batting.walks == 1 and is_equal_approx(team_batting.on_base_percentage, 0.5), "Team batting totals aggregate event-derived offense.", exit_code)
	exit_code = _expect(pitcher.outs_recorded == 3 and pitcher.innings_pitched_display == "1.0" and is_equal_approx(pitcher.innings_pitched, 1.0), "Pitching stores integer outs and derives innings display separately.", exit_code)
	exit_code = _expect(pitcher.hits_allowed == 2 and pitcher.runs_allowed == 2 and pitcher.walks_allowed == 1 and pitcher.strikeouts == 1 and is_equal_approx(pitcher.era, 18.0) and is_equal_approx(pitcher.whip, 3.0), "Pitching totals and formulas are calculated from the event log.", exit_code)
	exit_code = _expect(StatCalculator.outs_to_innings(4) == 4.0 / 3.0 and StatCalculator.outs_to_display_innings(4) == "1.1", "Four pitching outs are stored as 4 and displayed as 1.1 innings.", exit_code)

	exit_code = _run_expanded_details_tests(exit_code)

	quit(exit_code)

func _run_expanded_details_tests(exit_code: int) -> int:
	var away = TeamModel.new("away2", "comp", "Away 2")
	var home = TeamModel.new("home2", "comp", "Home 2")
	var players = [
		PlayerModel.new("b1", "away2", "Single Batter"),
		PlayerModel.new("b2", "away2", "Double Batter"),
		PlayerModel.new("b3", "away2", "Triple Batter"),
		PlayerModel.new("b4", "away2", "Homer Batter"),
		PlayerModel.new("b5", "away2", "Walk Batter"),
		PlayerModel.new("b6", "away2", "HBP Batter"),
		PlayerModel.new("b7", "away2", "Strikeout Batter"),
		PlayerModel.new("b8", "away2", "Groundout Batter"),
		PlayerModel.new("b9", "away2", "Flyout Batter"),
		PlayerModel.new("p1", "home2", "Pitcher"),
	]
	var game = GameModel.new("game_2", "comp")
	game.away_team_id = "away2"
	game.home_team_id = "home2"
	var events = [
		_event2("x1", 1, {"event_type": "single", "batter_id": "b1", "pitcher_id": "p1", "count": {"total_pitches": 3}, "rbi": 0}),
		_event2("x2", 2, {"event_type": "double", "batter_id": "b2", "pitcher_id": "p1", "count": {"total_pitches": 4}, "runner_advancements": [{"runner_id": "b1", "end_base": "HOME", "scored": true}], "runs_scored": 1, "rbi": 1}),
		_event2("x3", 3, {"event_type": "triple", "batter_id": "b3", "pitcher_id": "p1", "count": {"total_pitches": 2}}),
		_event2("x4", 4, {"event_type": "home_run", "batter_id": "b4", "pitcher_id": "p1", "count": {"total_pitches": 5}, "runner_advancements": [{"runner_id": "b3", "end_base": "HOME", "scored": true}], "runs_scored": 2, "rbi": 2, "manual_overrides": {"earned_runs": 1}}),
		_event2("x5", 5, {"event_type": "walk", "batter_id": "b5", "pitcher_id": "p1", "count": {"total_pitches": 6}}),
		_event2("x6", 6, {"event_type": "hit_by_pitch", "batter_id": "b6", "pitcher_id": "p1", "count": {"total_pitches": 1}}),
		_event2("x7", 7, {"event_type": "strikeout", "batter_id": "b7", "pitcher_id": "p1", "count": {"total_pitches": 4}, "outs_added": 1}),
		_event2("x8", 8, {"event_type": "groundout", "batter_id": "b8", "pitcher_id": "p1", "count": {"total_pitches": 2}, "outs_added": 1}),
		_event2("x9", 9, {"event_type": "flyout", "batter_id": "b9", "pitcher_id": "p1", "count": {"total_pitches": 3}, "outs_added": 1, "manual_overrides": {"sacrifice_fly": true, "rbi": 1}, "runner_advancements": [{"runner_id": "b5", "end_base": "HOME", "scored": true}], "runs_scored": 1}),
	]
	var stats = StatCalculator.calculate([game], events, players, [away, home])
	var team = stats.team_batting.away2
	var pitcher = stats.player_pitching.p1
	exit_code = _expect(team.plate_appearances == 9 and team.at_bats == 6 and team.hits == 4 and team.singles == 1 and team.doubles == 1 and team.triples == 1 and team.home_runs == 1, "Expanded details drive first-batch hit and PA/AB batting totals.", exit_code)
	exit_code = _expect(team.walks == 1 and team.hit_by_pitch == 1 and team.strikeouts == 1 and team.sacrifice_flies == 1 and team.rbi == 4 and team.runs == 4, "Expanded details drive walks, HBP, SO, SF, RBI, and runs.", exit_code)
	exit_code = _expect(team.total_bases == 10 and is_equal_approx(team.batting_average, 4.0 / 6.0) and is_equal_approx(team.on_base_percentage, 6.0 / 9.0) and is_equal_approx(team.slugging_percentage, 10.0 / 6.0) and is_equal_approx(team.ops, team.on_base_percentage + team.slugging_percentage), "Expanded details derive AVG/OBP/SLG/OPS formulas.", exit_code)
	exit_code = _expect(stats.player_batting.b1.runs == 1 and stats.player_batting.b3.runs == 1 and stats.player_batting.b5.runs == 1, "Runner advancements credit scored runner runs.", exit_code)
	exit_code = _expect(pitcher.outs_recorded == 3 and pitcher.hits_allowed == 4 and pitcher.runs_allowed == 4 and pitcher.earned_runs == 3 and pitcher.walks_allowed == 1 and pitcher.strikeouts == 1 and pitcher.hit_batters == 1 and pitcher.home_runs_allowed == 1 and pitcher.pitch_count == 30, "Expanded details drive pitching totals, earned-run override, and pitch count.", exit_code)
	return exit_code

func _event2(id: String, sequence_number: int, details: Dictionary) -> GameEvent:
	var event = GameEventModel.new(id, "game_2")
	event.sequence_number = sequence_number
	event.offense_team_id = "away2"
	event.defense_team_id = "home2"
	event.details = details
	return event

func _event(id: String, sequence_number: int, event_type: String, batter_id: String, pitcher_id: String, runs_scored: int, outs_added: int, details: Dictionary) -> GameEvent:
	var event = GameEventModel.new(id, "game_1")
	event.sequence_number = sequence_number
	event.event_type = event_type
	event.batter_id = batter_id
	event.pitcher_id = pitcher_id
	event.offense_team_id = "away"
	event.defense_team_id = "home"
	event.runs_scored = runs_scored
	event.rbi_count = int(details.get("rbi", runs_scored))
	event.outs_added = outs_added
	event.outs_after = outs_added
	event.details = details
	return event

func _expect(condition: bool, message: String, current_exit_code: int) -> int:
	if not condition:
		push_error(message)
		return 1
	return current_exit_code
