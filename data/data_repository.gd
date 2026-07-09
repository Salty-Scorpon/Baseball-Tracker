class_name DataRepository
extends RefCounted

const SCHEMA_VERSION := 1

const CompetitionModel := preload("res://data/models/competition.gd")
const GameModel := preload("res://data/models/game.gd")
const GameEventModel := preload("res://data/models/game_event.gd")
const ManualStatEntryModel := preload("res://data/models/manual_stat_entry.gd")
const PlayerModel := preload("res://data/models/player.gd")
const RulesetModel := preload("res://data/models/ruleset.gd")
const TeamModel := preload("res://data/models/team.gd")

var schema_version: int = SCHEMA_VERSION
var competitions: Array[Competition] = []
var teams: Array[Team] = []
var players: Array[Player] = []
var games: Array[Game] = []
var rulesets: Array[Ruleset] = []
var game_events: Array[GameEvent] = []
var manual_stat_entries: Array[ManualStatEntry] = []

func new_project() -> void:
	schema_version = SCHEMA_VERSION
	competitions.clear()
	teams.clear()
	players.clear()
	games.clear()
	rulesets.clear()
	game_events.clear()
	manual_stat_entries.clear()

func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"competitions": _items_to_dicts(competitions),
		"teams": _items_to_dicts(teams),
		"players": _items_to_dicts(players),
		"games": _items_to_dicts(games),
		"rulesets": _items_to_dicts(rulesets),
		"game_events": _items_to_dicts(game_events),
		"manual_stat_entries": _items_to_dicts(manual_stat_entries),
	}

static func from_dict(data: Dictionary) -> DataRepository:
	var repository := DataRepository.new()
	repository.schema_version = int(data.get("schema_version", SCHEMA_VERSION))
	repository.competitions.assign(_collection_from_dicts(data.get("competitions", []), CompetitionModel))
	repository.teams.assign(_collection_from_dicts(data.get("teams", []), TeamModel))
	repository.players.assign(_collection_from_dicts(data.get("players", []), PlayerModel))
	repository.games.assign(_collection_from_dicts(data.get("games", []), GameModel))
	repository.rulesets.assign(_collection_from_dicts(data.get("rulesets", []), RulesetModel))
	repository.game_events.assign(_collection_from_dicts(data.get("game_events", []), GameEventModel))
	repository.manual_stat_entries.assign(_collection_from_dicts(data.get("manual_stat_entries", []), ManualStatEntryModel))
	return repository

func add_competition(competition: Competition) -> bool:
	if competition == null or competition.id.is_empty() or find_entity_by_id(competition.id) != null:
		return false
	competitions.append(competition)
	return true

func add_team(team: Team) -> bool:
	if team == null or team.id.is_empty() or find_entity_by_id(team.id) != null:
		return false
	teams.append(team)
	var competition: Competition = find_entity_by_id(team.competition_id, "competitions")
	if competition != null:
		competition.add_team_id(team.id)
	return true

func add_player(player: Player) -> bool:
	if player == null or player.id.is_empty() or find_entity_by_id(player.id) != null:
		return false
	players.append(player)
	var team: Team = find_entity_by_id(player.team_id, "teams")
	if team != null:
		team.add_player_id(player.id)
	return true

func add_game(game: Game) -> bool:
	if game == null or game.id.is_empty() or find_entity_by_id(game.id) != null:
		return false
	games.append(game)
	var competition: Competition = find_entity_by_id(game.competition_id, "competitions")
	if competition != null:
		competition.add_game_id(game.id)
	for team_id in [game.home_team_id, game.away_team_id]:
		var team: Team = find_entity_by_id(team_id, "teams")
		if team != null:
			team.add_game_id(game.id)
	return true

func add_ruleset(ruleset: Ruleset) -> bool:
	if ruleset == null or ruleset.id.is_empty() or find_entity_by_id(ruleset.id) != null:
		return false
	rulesets.append(ruleset)
	return true

func add_manual_stat_entry(entry: ManualStatEntry) -> bool:
	if entry == null or entry.id.is_empty() or find_entity_by_id(entry.id) != null:
		return false
	manual_stat_entries.append(entry)
	return true

func add_game_event(event: GameEvent) -> bool:
	if event == null or event.id.is_empty() or find_entity_by_id(event.id) != null:
		return false
	game_events.append(event)
	var game: Game = find_entity_by_id(event.game_id, "games")
	if game != null and not game.event_ids.has(event.id):
		game.event_ids.append(event.id)
	return true

func find_entity_by_id(entity_id: String, collection_name: String = "") -> Variant:
	if entity_id.is_empty():
		return null
	var collections := _collections_for_lookup(collection_name)
	for collection in collections:
		for entity in collection:
			if entity.id == entity_id:
				return entity
	return null

func validate_broken_references() -> PackedStringArray:
	var errors := PackedStringArray()
	for competition in competitions:
		if not competition.ruleset_id.is_empty() and find_entity_by_id(competition.ruleset_id, "rulesets") == null:
			errors.append("Competition %s references missing ruleset %s." % [competition.id, competition.ruleset_id])
		for team_id in competition.team_ids:
			if find_entity_by_id(team_id, "teams") == null:
				errors.append("Competition %s references missing team %s." % [competition.id, team_id])
		for game_id in competition.game_ids:
			if find_entity_by_id(game_id, "games") == null:
				errors.append("Competition %s references missing game %s." % [competition.id, game_id])
	for team in teams:
		if find_entity_by_id(team.competition_id, "competitions") == null:
			errors.append("Team %s references missing competition %s." % [team.id, team.competition_id])
		for player_id in team.roster_player_ids:
			if find_entity_by_id(player_id, "players") == null:
				errors.append("Team %s references missing player %s." % [team.id, player_id])
		for game_id in team.game_ids:
			if find_entity_by_id(game_id, "games") == null:
				errors.append("Team %s references missing game %s." % [team.id, game_id])
	for player in players:
		if find_entity_by_id(player.team_id, "teams") == null:
			errors.append("Player %s references missing team %s." % [player.id, player.team_id])
	for game in games:
		if find_entity_by_id(game.competition_id, "competitions") == null:
			errors.append("Game %s references missing competition %s." % [game.id, game.competition_id])
		if find_entity_by_id(game.home_team_id, "teams") == null:
			errors.append("Game %s references missing home team %s." % [game.id, game.home_team_id])
		if find_entity_by_id(game.away_team_id, "teams") == null:
			errors.append("Game %s references missing away team %s." % [game.id, game.away_team_id])
		for event_id in game.event_ids:
			if find_entity_by_id(event_id, "game_events") == null:
				errors.append("Game %s references missing event %s." % [game.id, event_id])
	for event in game_events:
		if find_entity_by_id(event.game_id, "games") == null:
			errors.append("GameEvent %s references missing game %s." % [event.id, event.game_id])
		for team_id in [event.offensive_team_id, event.defensive_team_id]:
			if not team_id.is_empty() and find_entity_by_id(team_id, "teams") == null:
				errors.append("GameEvent %s references missing team %s." % [event.id, team_id])
		for player_id in [event.batter_id, event.pitcher_id] + event.fielder_ids + event.runner_ids:
			if not player_id.is_empty() and find_entity_by_id(player_id, "players") == null:
				errors.append("GameEvent %s references missing player %s." % [event.id, player_id])
	for entry in manual_stat_entries:
		if find_entity_by_id(entry.competition_id, "competitions") == null:
			errors.append("ManualStatEntry %s references missing competition %s." % [entry.id, entry.competition_id])
		if entry.subject_type == "team" and find_entity_by_id(entry.subject_id, "teams") == null:
			errors.append("ManualStatEntry %s references missing team %s." % [entry.id, entry.subject_id])
		if entry.subject_type == "player" and find_entity_by_id(entry.subject_id, "players") == null:
			errors.append("ManualStatEntry %s references missing player %s." % [entry.id, entry.subject_id])
	return errors

static func _items_to_dicts(items: Array) -> Array:
	var output: Array = []
	for item in items:
		output.append(item.to_dict())
	return output

static func _collection_from_dicts(items: Variant, model: Variant) -> Array:
	var output: Array = []
	if items is Array:
		for item in items:
			if item is Dictionary:
				output.append(model.from_dict(item))
	return output

func _collections_for_lookup(collection_name: String) -> Array:
	match collection_name:
		"competitions": return [competitions]
		"teams": return [teams]
		"players": return [players]
		"games": return [games]
		"rulesets": return [rulesets]
		"game_events": return [game_events]
		"manual_stat_entries": return [manual_stat_entries]
		_: return [competitions, teams, players, games, rulesets, game_events, manual_stat_entries]
