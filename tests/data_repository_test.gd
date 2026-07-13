extends SceneTree

const DataRepositoryScript = preload("res://data/data_repository.gd")
const TeamModel = preload("res://data/models/team.gd")

func _init() -> void:
	var exit_code = 0
	var repository = DataRepositoryScript.new()
	var team = TeamModel.new("team_test", "competition_test", "Test Team")
	repository.add_team(team)

	var player = repository.create_player_for_team("team_test", {
		"jersey_number": "12",
		"first_name": "Taro",
		"last_name": "Yamada",
		"position": "P, IF",
	})
	if player == null:
		push_error("Expected player creation to succeed.")
		exit_code = 1
	elif player.positions != ["P", "IF"]:
		push_error("Expected comma-separated positions to be parsed, got %s." % [player.positions])
		exit_code = 1
	elif not team.roster_player_ids.has(player.id):
		push_error("Expected created player to be added to team roster.")
		exit_code = 1

	var array_player = repository.create_player_for_team("team_test", {
		"first_name": "Ken",
		"last_name": "Sato",
		"positions": ["C", " OF "],
	})
	if array_player == null:
		push_error("Expected player creation from positions array to succeed.")
		exit_code = 1
	elif array_player.positions != ["C", "OF"]:
		push_error("Expected positions array to be normalized, got %s." % [array_player.positions])
		exit_code = 1

	quit(exit_code)
