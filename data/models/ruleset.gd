class_name Ruleset
extends RefCounted

const DEFAULT_ID := "ruleset_standard_baseball"

var id: String
var name: String
var innings: int
var allow_ties: bool
var mercy_rule: Dictionary
var allow_reentry: bool
var pitch_count_enabled: bool
var notes: String

func _init(p_id: String = "", p_name: String = "Standard Baseball") -> void:
	id = p_id if not p_id.is_empty() else DEFAULT_ID
	name = p_name
	innings = 9
	allow_ties = false
	mercy_rule = {}
	allow_reentry = false
	pitch_count_enabled = false
	notes = ""

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"innings": innings,
		"allow_ties": allow_ties,
		"mercy_rule": mercy_rule.duplicate(true),
		"allow_reentry": allow_reentry,
		"pitch_count_enabled": pitch_count_enabled,
		"notes": notes,
	}

static func from_dict(data: Dictionary) -> Ruleset:
	var ruleset := Ruleset.new(str(data.get("id", "")), str(data.get("name", "Standard Baseball")))
	ruleset.innings = int(data.get("innings", 9))
	ruleset.allow_ties = bool(data.get("allow_ties", false))
	ruleset.mercy_rule = Dictionary(data.get("mercy_rule", {})).duplicate(true)
	ruleset.allow_reentry = bool(data.get("allow_reentry", false))
	ruleset.pitch_count_enabled = bool(data.get("pitch_count_enabled", false))
	ruleset.notes = str(data.get("notes", ""))
	return ruleset

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.strip_edges().is_empty():
		errors.append("Ruleset id is required.")
	if name.strip_edges().is_empty():
		errors.append("Ruleset name is required.")
	if innings <= 0:
		errors.append("Ruleset innings must be greater than zero.")
	return errors
