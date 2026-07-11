class_name Player
extends RefCounted

var id: String
var team_id: String
var first_name: String
var last_name: String
var display_name: String
var japanese_name: String
var kana_reading: String
var jersey_number: String
var grade: String
var positions: Array[String]
var throws_hand: String
var bats: String
var height: Variant
var weight: Variant
var notes: String

func _init(p_id: String = "", p_team_id: String = "", p_display_name: String = "") -> void:
	id = p_id
	team_id = p_team_id
	first_name = ""
	last_name = ""
	display_name = p_display_name
	japanese_name = ""
	kana_reading = ""
	jersey_number = ""
	grade = ""
	positions = []
	throws_hand = "Unknown"
	bats = "Unknown"
	height = null
	weight = null
	notes = ""

func to_dict() -> Dictionary:
	return {
		"id": id,
		"team_id": team_id,
		"first_name": first_name,
		"last_name": last_name,
		"display_name": display_name,
		"japanese_name": japanese_name,
		"kana_reading": kana_reading,
		"jersey_number": jersey_number,
		"grade": grade,
		"positions": positions.duplicate(),
		"throws_hand": throws_hand,
		"bats": bats,
		"height": height,
		"weight": weight,
		"notes": notes,
	}

static func from_dict(data: Dictionary) -> Player:
	var player = Player.new(str(data.get("id", "")), str(data.get("team_id", "")), str(data.get("display_name", "")))
	player.first_name = str(data.get("first_name", ""))
	player.last_name = str(data.get("last_name", ""))
	player.japanese_name = str(data.get("japanese_name", ""))
	player.kana_reading = str(data.get("kana_reading", ""))
	player.jersey_number = str(data.get("jersey_number", ""))
	player.grade = str(data.get("grade", ""))
	player.positions.assign(data.get("positions", []))
	player.throws_hand = str(data.get("throws_hand", "Unknown"))
	player.bats = str(data.get("bats", "Unknown"))
	player.height = data.get("height", null)
	player.weight = data.get("weight", null)
	player.notes = str(data.get("notes", ""))
	return player

func validate() -> PackedStringArray:
	var errors = PackedStringArray()
	if id.strip_edges().is_empty(): errors.append("Player id is required.")
	if team_id.strip_edges().is_empty(): errors.append("Player team_id is required.")
	if display_name.strip_edges().is_empty() and first_name.strip_edges().is_empty() and last_name.strip_edges().is_empty():
		errors.append("Player name is required.")
	return errors
