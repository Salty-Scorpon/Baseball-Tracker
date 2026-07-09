class_name SampleDataFactory
extends RefCounted

const CompetitionModel := preload("res://data/models/competition.gd")
const GameModel := preload("res://data/models/game.gd")
const PlayerModel := preload("res://data/models/player.gd")
const RulesetModel := preload("res://data/models/ruleset.gd")
const TeamModel := preload("res://data/models/team.gd")

static func create_sample_competition() -> Dictionary:
	var ruleset := RulesetModel.new("ruleset_jhs_baseball", "Japanese High School Baseball")
	ruleset.innings = 9

	var competition := CompetitionModel.new("competition_sample_001", "Sample Summer Baseball Tournament")
	competition.year = 2026
	competition.location = "Sample Region"
	competition.ruleset_id = ruleset.id
	competition.start_date = "2026-08-01"
	competition.end_date = "2026-08-15"

	var home_team := TeamModel.new("team_sample_home", competition.id, "Koyo High")
	home_team.region = "East"
	home_team.abbreviation = "KOY"
	var away_team := TeamModel.new("team_sample_away", competition.id, "Seiran High")
	away_team.region = "West"
	away_team.abbreviation = "SEI"

	competition.add_team_id(home_team.id)
	competition.add_team_id(away_team.id)

	var players: Array[Player] = []
	for index in range(1, 4):
		var player := PlayerModel.new("player_koyo_%02d" % index, home_team.id, "Koyo Player %d" % index)
		player.jersey_number = str(index)
		player.positions = ["P" if index == 1 else "IF"]
		home_team.add_player_id(player.id)
		players.append(player)
	for index in range(1, 4):
		var player := PlayerModel.new("player_seiran_%02d" % index, away_team.id, "Seiran Player %d" % index)
		player.jersey_number = str(index)
		player.positions = ["P" if index == 1 else "OF"]
		away_team.add_player_id(player.id)
		players.append(player)

	var game := GameModel.new("game_sample_001", competition.id)
	game.home_team_id = home_team.id
	game.away_team_id = away_team.id
	game.date = "2026-08-02"
	game.start_time = "09:00"
	game.venue = "Sample Stadium"
	game.round = "Opening Round"
	game.game_number = "1"
	competition.add_game_id(game.id)
	home_team.add_game_id(game.id)
	away_team.add_game_id(game.id)

	return {"competition": competition, "rulesets": [ruleset], "teams": [home_team, away_team], "players": players, "games": [game], "events": [], "manual_stat_entries": []}

static func validate_sample(sample: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for key in ["competition", "rulesets", "teams", "players", "games"]:
		if not sample.has(key): errors.append("Sample missing %s." % key)
	for collection_key in ["rulesets", "teams", "players", "games"]:
		for item in sample.get(collection_key, []):
			errors.append_array(item.validate())
	if sample.has("competition"):
		errors.append_array(sample["competition"].validate())
	return errors
