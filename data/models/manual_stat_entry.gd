class_name ManualStatEntry
extends RefCounted

var id: String
var competition_id: String
var subject_type: String
var subject_id: String
var stat_scope: String
var stats: Dictionary
var source: String
var notes: String
var created_at: String
var manual: bool

func _init(p_id: String = "", p_competition_id: String = "", p_subject_type: String = "", p_subject_id: String = "") -> void:
	id = p_id
	competition_id = p_competition_id
	subject_type = p_subject_type
	subject_id = p_subject_id
	stat_scope = "overall"
	stats = {}
	source = ""
	notes = ""
	created_at = ""
	manual = true

func to_dict() -> Dictionary:
	return {"id": id, "competition_id": competition_id, "subject_type": subject_type, "subject_id": subject_id, "stat_scope": stat_scope, "stats": stats.duplicate(true), "source": source, "notes": notes, "created_at": created_at, "manual": manual}

static func from_dict(data: Dictionary) -> ManualStatEntry:
	var entry = ManualStatEntry.new(str(data.get("id", "")), str(data.get("competition_id", "")), str(data.get("subject_type", "")), str(data.get("subject_id", "")))
	entry.stat_scope = str(data.get("stat_scope", "overall"))
	entry.stats = Dictionary(data.get("stats", {})).duplicate(true)
	entry.source = str(data.get("source", ""))
	entry.notes = str(data.get("notes", ""))
	entry.created_at = str(data.get("created_at", ""))
	entry.manual = bool(data.get("manual", true))
	return entry

func validate() -> PackedStringArray:
	var errors = PackedStringArray()
	if id.strip_edges().is_empty(): errors.append("ManualStatEntry id is required.")
	if competition_id.strip_edges().is_empty(): errors.append("ManualStatEntry competition_id is required.")
	if not ["team", "player"].has(subject_type): errors.append("ManualStatEntry subject_type must be team or player.")
	if subject_id.strip_edges().is_empty(): errors.append("ManualStatEntry subject_id is required.")
	return errors
