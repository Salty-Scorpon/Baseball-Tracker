class_name Team
extends RefCounted

var id: String
var competition_id: String
var name: String
var school_name: String
var region: String
var short_name: String
var abbreviation: String
var coach_name: String
var colors: Array[String]
var notes: String
var roster_player_ids: Array[String]
var game_ids: Array[String]

func _init(p_id: String = "", p_competition_id: String = "", p_name: String = "") -> void:
	id = p_id
	competition_id = p_competition_id
	name = p_name
	school_name = ""
	region = ""
	short_name = ""
	abbreviation = ""
	coach_name = ""
	colors = []
	notes = ""
	roster_player_ids = []
	game_ids = []

func to_dict() -> Dictionary:
	return {
		"id": id,
		"competition_id": competition_id,
		"name": name,
		"school_name": school_name,
		"region": region,
		"short_name": short_name,
		"abbreviation": abbreviation,
		"coach_name": coach_name,
		"colors": colors.duplicate(),
		"notes": notes,
		"roster_player_ids": roster_player_ids.duplicate(),
		"game_ids": game_ids.duplicate(),
	}

static func from_dict(data: Dictionary) -> Team:
	var team = Team.new(str(data.get("id", "")), str(data.get("competition_id", "")), str(data.get("name", "")))
	team.school_name = str(data.get("school_name", ""))
	team.region = str(data.get("region", ""))
	team.short_name = str(data.get("short_name", ""))
	team.abbreviation = str(data.get("abbreviation", ""))
	team.coach_name = str(data.get("coach_name", ""))
	team.colors.assign(data.get("colors", []))
	team.notes = str(data.get("notes", ""))
	team.roster_player_ids.assign(data.get("roster_player_ids", []))
	team.game_ids.assign(data.get("game_ids", []))
	return team

func add_player_id(player_id: String) -> void:
	if not player_id.is_empty() and not roster_player_ids.has(player_id):
		roster_player_ids.append(player_id)

func add_game_id(game_id: String) -> void:
	if not game_id.is_empty() and not game_ids.has(game_id):
		game_ids.append(game_id)

func validate() -> PackedStringArray:
	var errors = PackedStringArray()
	if id.strip_edges().is_empty():
		errors.append("Team id is required.")
	if competition_id.strip_edges().is_empty():
		errors.append("Team competition_id is required.")
	if name.strip_edges().is_empty():
		errors.append("Team name is required.")
	return errors
