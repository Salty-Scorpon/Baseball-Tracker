class_name CsvImporter
extends RefCounted

const TeamModel = preload("res://data/models/team.gd")
const PlayerModel = preload("res://data/models/player.gd")
const CompetitionModel = preload("res://data/models/competition.gd")

const DEFAULT_COMPETITION_ID = "competition_imported_rosters"
const DEFAULT_COMPETITION_NAME = "Imported Rosters"
const REQUIRED_COLUMNS = ["team_name", "player_name"]
const COLUMN_ALIASES = {
	"team_name": ["team", "team name", "team_name", "school", "school_name", "school name"],
	"region": ["region", "prefecture", "area"],
	"jersey_number": ["jersey", "jersey_number", "jersey number", "number", "no", "#"],
	"player_name": ["player", "player_name", "player name", "name", "display_name", "display name"],
	"position": ["position", "positions", "pos"],
	"bats": ["bats", "bat", "b"],
	"throws": ["throws", "throw", "throws_hand", "throws hand", "t"],
	"grade": ["grade", "year", "class"],
	"first_name": ["first_name", "first name", "given_name", "given name"],
	"last_name": ["last_name", "last name", "family_name", "family name", "surname"],
	"japanese_name": ["japanese_name", "japanese name", "kanji"],
	"kana_reading": ["kana_reading", "kana reading", "kana"],
	"notes": ["notes", "note"]
}

class ImportResult:
	var teams_created: Array[Team] = []
	var teams_reused: Array[Team] = []
	var players_created: Array[Player] = []
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()

	func succeeded() -> bool:
		return errors.is_empty()

func import_text(repository: DataRepository, text: String, column_mapping: Dictionary = {}) -> ImportResult:
	var result = ImportResult.new()
	if repository == null:
		result.errors.append("Import requires a data repository.")
		return result
	var rows = _parse_table(text, result)
	if not result.errors.is_empty():
		return result
	if rows.size() < 2:
		result.errors.append("Import text must include a header row and at least one data row.")
		return result
	var headers: Array = rows[0]
	var mapping = _build_mapping(headers, column_mapping)
	_validate_required_columns(mapping, result)
	if not result.errors.is_empty():
		return result
	var competition_id = _ensure_import_competition(repository)
	var teams_by_key = _existing_teams_by_key(repository, competition_id)
	var players_seen = {}
	var pending_teams: Array[Team] = []
	var pending_players: Array[Player] = []
	for row_index in range(1, rows.size()):
		var row: Array = rows[row_index]
		if _row_is_empty(row):
			continue
		var row_number = row_index + 1
		var data = _row_to_data(row, mapping)
		var team_name = str(data.get("team_name", "")).strip_edges()
		var player_name = str(data.get("player_name", "")).strip_edges()
		if team_name.is_empty():
			result.errors.append("Row %d: team_name is required." % row_number)
			continue
		if player_name.is_empty() and str(data.get("first_name", "")).strip_edges().is_empty() and str(data.get("last_name", "")).strip_edges().is_empty():
			result.errors.append("Row %d: player_name is required." % row_number)
			continue
		var region = str(data.get("region", "")).strip_edges()
		var team_key = _team_key(competition_id, team_name, region)
		var team: Team = teams_by_key.get(team_key)
		if team == null:
			team = TeamModel.new(_unique_id(repository, "team", team_name), competition_id, team_name)
			team.region = region
			teams_by_key[team_key] = team
			pending_teams.append(team)
		else:
			if not result.teams_reused.has(team) and not pending_teams.has(team):
				result.teams_reused.append(team)
		var player = PlayerModel.new(_unique_id(repository, "player", "%s_%s" % [team_name, player_name]), team.id, player_name)
		_apply_player_fields(player, data)
		var player_errors = player.validate()
		if not player_errors.is_empty():
			for error in player_errors:
				result.errors.append("Row %d: %s" % [row_number, error])
			continue
		var player_key = "%s|%s|%s" % [team.id, player.jersey_number, player.display_name.to_lower()]
		if players_seen.has(player_key):
			result.warnings.append("Row %d: possible duplicate player %s on %s." % [row_number, player.display_name, team.name])
		players_seen[player_key] = true
		pending_players.append(player)
	if not result.errors.is_empty():
		return result
	for team in pending_teams:
		if repository.add_team(team):
			result.teams_created.append(team)
	for player in pending_players:
		if repository.add_player(player):
			result.players_created.append(player)
	return result

func _parse_table(text: String, result: ImportResult) -> Array:
	var rows = []
	var clean_text = text.strip_edges()
	if clean_text.is_empty():
		result.errors.append("Import text is empty.")
		return rows
	var delimiter = "\t" if clean_text.contains("\t") else ","
	for line in clean_text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
		rows.append(_parse_delimited_line(line, delimiter))
	return rows

func _parse_delimited_line(line: String, delimiter: String) -> Array:
	if delimiter == "\t":
		var tab_parts: Array = []
		for part in line.split("\t", true): tab_parts.append(part.strip_edges())
		return tab_parts
	var fields: Array = []
	var current = ""
	var in_quotes = false
	var i = 0
	while i < line.length():
		var c = line.substr(i, 1)
		if c == "\"":
			if in_quotes and i + 1 < line.length() and line.substr(i + 1, 1) == "\"":
				current += "\""
				i += 1
			else:
				in_quotes = not in_quotes
		elif c == delimiter and not in_quotes:
			fields.append(current.strip_edges())
			current = ""
		else:
			current += c
		i += 1
	fields.append(current.strip_edges())
	return fields

func _build_mapping(headers: Array, overrides: Dictionary) -> Dictionary:
	var mapping = {}
	for canonical in COLUMN_ALIASES.keys():
		if overrides.has(canonical):
			mapping[canonical] = int(overrides[canonical])
			continue
		for i in range(headers.size()):
			var normalized = _normalize_header(str(headers[i]))
			if COLUMN_ALIASES[canonical].has(normalized):
				mapping[canonical] = i
				break
	return mapping

func _validate_required_columns(mapping: Dictionary, result: ImportResult) -> void:
	for column in REQUIRED_COLUMNS:
		if not mapping.has(column):
			result.errors.append("Missing required column: %s." % column)

func _row_to_data(row: Array, mapping: Dictionary) -> Dictionary:
	var data = {}
	for key in mapping.keys():
		var index = int(mapping[key])
		data[key] = str(row[index]).strip_edges() if index >= 0 and index < row.size() else ""
	return data

func _apply_player_fields(player: Player, data: Dictionary) -> void:
	player.first_name = str(data.get("first_name", "")).strip_edges()
	player.last_name = str(data.get("last_name", "")).strip_edges()
	if player.display_name.is_empty():
		player.display_name = "%s %s" % [player.first_name, player.last_name]
		player.display_name = player.display_name.strip_edges()
	player.japanese_name = str(data.get("japanese_name", "")).strip_edges()
	player.kana_reading = str(data.get("kana_reading", "")).strip_edges()
	player.jersey_number = str(data.get("jersey_number", "")).strip_edges()
	player.grade = str(data.get("grade", "")).strip_edges()
	player.bats = _normalize_hand(str(data.get("bats", "")))
	player.throws_hand = _normalize_hand(str(data.get("throws", "")))
	var position = str(data.get("position", "")).strip_edges()
	if not position.is_empty():
		player.positions.assign(position.split(",", false))
	player.notes = str(data.get("notes", "")).strip_edges()

func _normalize_hand(value: String) -> String:
	match value.strip_edges().to_lower():
		"l", "left": return "Left"
		"r", "right": return "Right"
		"s", "switch": return "Switch"
		_: return "Unknown"

func _ensure_import_competition(repository: DataRepository) -> String:
	if repository.find_entity_by_id(DEFAULT_COMPETITION_ID, "competitions") == null:
		repository.add_competition(CompetitionModel.new(DEFAULT_COMPETITION_ID, DEFAULT_COMPETITION_NAME))
	return DEFAULT_COMPETITION_ID

func _existing_teams_by_key(repository: DataRepository, competition_id: String) -> Dictionary:
	var teams = {}
	for team in repository.teams:
		if team.competition_id == competition_id:
			teams[_team_key(competition_id, team.name, team.region)] = team
	return teams

func _team_key(competition_id: String, team_name: String, region: String) -> String:
	return "%s|%s|%s" % [competition_id, team_name.strip_edges().to_lower(), region.strip_edges().to_lower()]

func _unique_id(repository: DataRepository, prefix: String, label: String) -> String:
	var base = "%s_%s" % [prefix, _slug(label)]
	var candidate = base
	var index = 2
	while repository.find_entity_by_id(candidate) != null:
		candidate = "%s_%d" % [base, index]
		index += 1
	return candidate

func _slug(value: String) -> String:
	var output = ""
	for i in range(value.length()):
		var c = value.substr(i, 1).to_lower()
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			output += c
		elif not output.ends_with("_"):
			output += "_"
	output = output.strip_edges().trim_prefix("_").trim_suffix("_")
	return "imported" if output.is_empty() else output

func _normalize_header(header: String) -> String:
	return header.strip_edges().to_lower().replace("-", "_")

func _row_is_empty(row: Array) -> bool:
	for value in row:
		if not str(value).strip_edges().is_empty(): return false
	return true
