extends SceneTree

const SampleDataFactory = preload("res://data/sample_data_factory.gd")
const SaveManagerScript = preload("res://data/saving/save_manager.gd")

const SAVE_PATH = "user://save_system_smoke_test.json"

func _init() -> void:
	var exit_code = 0
	var repository = SaveManagerScript.new_project()
	var sample = SampleDataFactory.create_sample_competition()

	repository.add_ruleset(sample["rulesets"][0])
	repository.add_competition(sample["competition"])
	for team in sample["teams"]:
		repository.add_team(team)
	for player in sample["players"]:
		repository.add_player(player)
	for game in sample["games"]:
		repository.add_game(game)

	var reference_errors = repository.validate_broken_references()
	if not reference_errors.is_empty():
		push_error("Sample data has broken references before save: %s" % [reference_errors])
		exit_code = 1

	var save_error = SaveManagerScript.save_project(repository, SAVE_PATH)
	if save_error != OK:
		push_error("Save failed with error %d." % save_error)
		exit_code = 1

	repository.new_project()
	if not repository.competitions.is_empty() or not repository.teams.is_empty() or not repository.players.is_empty() or not repository.games.is_empty():
		push_error("Repository reset did not clear project data.")
		exit_code = 1

	var loaded = SaveManagerScript.load_project(SAVE_PATH)
	if loaded == null:
		push_error("Load returned null repository.")
		exit_code = 1
	else:
		var loaded_errors = loaded.validate_broken_references()
		if not loaded_errors.is_empty():
			push_error("Loaded data has broken references: %s" % [loaded_errors])
			exit_code = 1
		if not _assert_id(loaded.find_entity_by_id("competition_sample_001"), "competition_sample_001"):
			exit_code = 1
		if not _assert_id(loaded.find_entity_by_id("team_sample_home"), "team_sample_home"):
			exit_code = 1
		if not _assert_id(loaded.find_entity_by_id("player_koyo_01"), "player_koyo_01"):
			exit_code = 1
		if not _assert_id(loaded.find_entity_by_id("game_sample_001"), "game_sample_001"):
			exit_code = 1
		var loaded_game = loaded.find_entity_by_id("game_sample_001", "games")
		if loaded_game.home_team_id != "team_sample_home" or loaded_game.away_team_id != "team_sample_away":
			push_error("Loaded game relationships were not preserved.")
			exit_code = 1

	quit(exit_code)

func _assert_id(entity: Variant, expected_id: String) -> bool:
	if entity == null or entity.id != expected_id:
		push_error("Expected to find entity id %s." % expected_id)
		return false
	return true
