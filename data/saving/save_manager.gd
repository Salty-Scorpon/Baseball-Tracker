class_name SaveManager
extends RefCounted

const CURRENT_SCHEMA_VERSION = DataRepository.SCHEMA_VERSION
const DEFAULT_SAVE_PATH = "user://baseball_tracker_project.json"

static func new_project() -> DataRepository:
	var repository = DataRepository.new()
	repository.new_project()
	return repository

static func save_project(repository: DataRepository, file_path: String = DEFAULT_SAVE_PATH) -> Error:
	if repository == null:
		push_error("Cannot save a null DataRepository.")
		return ERR_INVALID_PARAMETER
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot open save file for writing: %s" % file_path)
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(repository.to_dict(), "\t"))
	return OK

static func load_project(file_path: String = DEFAULT_SAVE_PATH) -> DataRepository:
	if not FileAccess.file_exists(file_path):
		push_error("Save file does not exist: %s" % file_path)
		return null
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open save file for reading: %s" % file_path)
		return null
	var json = JSON.new()
	var parse_error = json.parse(file.get_as_text())
	if parse_error != OK:
		push_error("Cannot parse save file %s: %s at line %d" % [file_path, json.get_error_message(), json.get_error_line()])
		return null
	var parsed = json.data
	if not parsed is Dictionary:
		push_error("Save file root must be a JSON object: %s" % file_path)
		return null
	return DataRepository.from_dict(_migrate_to_current_schema(parsed))

static func _migrate_to_current_schema(data: Dictionary) -> Dictionary:
	var migrated = data.duplicate(true)
	var version = int(migrated.get("schema_version", 0))
	if version <= 0:
		version = 1
	migrated["schema_version"] = version
	for key in ["competitions", "teams", "players", "games", "rulesets", "game_events", "manual_stat_entries"]:
		if not migrated.has(key) or not migrated[key] is Array:
			migrated[key] = []
	return migrated
