class_name Competition
extends RefCounted

const DateUtils := preload("res://data/date_utils.gd")

var id: String
var name: String
var year: int
var location: String
var ruleset_id: String
var start_date: String
var end_date: String
var notes: String
var team_ids: Array[String]
var game_ids: Array[String]
var bracket: Dictionary

func _init(p_id: String = "", p_name: String = "") -> void:
	id = p_id
	name = p_name
	year = 0
	location = ""
	ruleset_id = ""
	start_date = ""
	end_date = ""
	notes = ""
	team_ids = []
	game_ids = []
	bracket = {}

func to_dict() -> Dictionary:
	return {"id": id, "name": name, "year": year, "location": location, "ruleset_id": ruleset_id, "start_date": start_date, "end_date": end_date, "notes": notes, "team_ids": team_ids.duplicate(), "game_ids": game_ids.duplicate(), "bracket": bracket.duplicate(true)}

static func from_dict(data: Dictionary) -> Competition:
	var competition := Competition.new(str(data.get("id", "")), str(data.get("name", "")))
	competition.year = int(data.get("year", 0))
	competition.location = str(data.get("location", ""))
	competition.ruleset_id = str(data.get("ruleset_id", ""))
	competition.start_date = str(data.get("start_date", ""))
	competition.end_date = str(data.get("end_date", ""))
	competition.notes = str(data.get("notes", ""))
	competition.team_ids.assign(data.get("team_ids", []))
	competition.game_ids.assign(data.get("game_ids", []))
	competition.bracket = Dictionary(data.get("bracket", {})).duplicate(true)
	return competition

func add_team_id(team_id: String) -> void:
	if not team_id.is_empty() and not team_ids.has(team_id): team_ids.append(team_id)

func add_game_id(game_id: String) -> void:
	if not game_id.is_empty() and not game_ids.has(game_id): game_ids.append(game_id)

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.strip_edges().is_empty(): errors.append("Competition id is required.")
	if name.strip_edges().is_empty(): errors.append("Competition name is required.")
	if year < 0: errors.append("Competition year cannot be negative.")
	if ruleset_id.strip_edges().is_empty(): errors.append("Competition ruleset_id is required.")
	if not DateUtils.is_valid_iso_date(start_date): errors.append("Competition start_date must use YYYY-MM-DD.")
	if not DateUtils.is_valid_iso_date(end_date): errors.append("Competition end_date must use YYYY-MM-DD.")
	if DateUtils.is_valid_iso_date(start_date) and DateUtils.is_valid_iso_date(end_date) and not start_date.is_empty() and not end_date.is_empty() and start_date > end_date:
		errors.append("Competition start_date cannot be after end_date.")
	return errors
