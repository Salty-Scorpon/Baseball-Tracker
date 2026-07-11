class_name Game
extends RefCounted

const DateUtils = preload("res://data/date_utils.gd")

var id: String
var competition_id: String
var home_team_id: String
var away_team_id: String
var date: String
var start_time: String
var venue: String
var round: String
var game_number: String
var status: String
var notes: String
var event_ids: Array[String]

func _init(p_id: String = "", p_competition_id: String = "") -> void:
	id = p_id
	competition_id = p_competition_id
	home_team_id = ""
	away_team_id = ""
	date = ""
	start_time = ""
	venue = ""
	round = ""
	game_number = ""
	status = "Scheduled"
	notes = ""
	event_ids = []

func to_dict() -> Dictionary:
	return {"id": id, "competition_id": competition_id, "home_team_id": home_team_id, "away_team_id": away_team_id, "date": date, "start_time": start_time, "venue": venue, "round": round, "game_number": game_number, "status": status, "notes": notes, "event_ids": event_ids.duplicate()}

static func from_dict(data: Dictionary) -> Game:
	var game = Game.new(str(data.get("id", "")), str(data.get("competition_id", "")))
	game.home_team_id = str(data.get("home_team_id", ""))
	game.away_team_id = str(data.get("away_team_id", ""))
	game.date = str(data.get("date", ""))
	game.start_time = str(data.get("start_time", ""))
	game.venue = str(data.get("venue", ""))
	game.round = str(data.get("round", ""))
	game.game_number = str(data.get("game_number", ""))
	game.status = str(data.get("status", "Scheduled"))
	game.notes = str(data.get("notes", ""))
	game.event_ids.assign(data.get("event_ids", []))
	return game

func validate() -> PackedStringArray:
	var errors = PackedStringArray()
	if id.strip_edges().is_empty(): errors.append("Game id is required.")
	if competition_id.strip_edges().is_empty(): errors.append("Game competition_id is required.")
	if home_team_id.strip_edges().is_empty(): errors.append("Game home_team_id is required.")
	if away_team_id.strip_edges().is_empty(): errors.append("Game away_team_id is required.")
	if home_team_id == away_team_id and not home_team_id.is_empty(): errors.append("Game home and away teams must be different IDs.")
	if not DateUtils.is_valid_iso_date(date): errors.append("Game date must use YYYY-MM-DD.")
	if not ["Scheduled", "In Progress", "Final", "Suspended", "Cancelled"].has(status): errors.append("Game status is invalid.")
	return errors
