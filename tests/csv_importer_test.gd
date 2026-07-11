extends SceneTree

const CsvImporterScript = preload("res://import_export/CsvImporter.gd")
const SaveManagerScript = preload("res://data/saving/save_manager.gd")

func _init() -> void:
	var exit_code = 0
	var repository = SaveManagerScript.new_project()
	var importer = CsvImporterScript.new()
	var text = "team_name,region,jersey_number,player_name,position,bats,throws,grade\nOsaka Toin,Osaka,1,Taro Yamada,P,R,R,3\nOsaka Toin,Osaka,2,Ken Sato,C,L,R,2"
	var result = importer.import_text(repository, text)
	if not result.errors.is_empty():
		push_error("Expected import to succeed: %s" % [result.errors])
		exit_code = 1
	if result.teams_created.size() != 1 or repository.teams.size() != 1:
		push_error("Expected repeated team rows to create one team.")
		exit_code = 1
	if result.players_created.size() != 2 or repository.players.size() != 2:
		push_error("Expected two imported players.")
		exit_code = 1
	if repository.teams.size() == 1 and repository.teams[0].roster_player_ids.size() != 2:
		push_error("Expected team-player relationships to be created.")
		exit_code = 1
	var tsv = "team\tnumber\tplayer\nSeiran\t7\tAoi Tanaka"
	var tsv_result = importer.import_text(repository, tsv)
	if not tsv_result.errors.is_empty() or tsv_result.players_created.size() != 1:
		push_error("Expected TSV alias import to succeed: %s" % [tsv_result.errors])
		exit_code = 1
	var bad_result = importer.import_text(repository, "team_name,region\nNo Player,Nowhere")
	if bad_result.errors.is_empty():
		push_error("Expected missing required columns to report errors.")
		exit_code = 1
	quit(exit_code)
